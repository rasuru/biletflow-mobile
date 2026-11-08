import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef JsonObject = Map<String, dynamic>;

String _instant(DateTime value) => value.toUtc().toIso8601String();
String _segment(String value) => Uri.encodeComponent(value);

enum EventVisibility {
  publicEvent('PUBLIC'),
  unlisted('UNLISTED'),
  privateEvent('PRIVATE');

  const EventVisibility(this.wireValue);
  final String wireValue;
}

class RegistrationWindow {
  const RegistrationWindow.alwaysOpen()
    : _mode = 'ALWAYS_OPEN',
      startAt = null,
      endAt = null;

  const RegistrationWindow.opensAt(DateTime start)
    : _mode = 'OPENS_AT',
      startAt = start,
      endAt = null;

  const RegistrationWindow.bounded(DateTime start, DateTime end)
    : _mode = 'BOUNDED',
      startAt = start,
      endAt = end;

  final String _mode;
  final DateTime? startAt;
  final DateTime? endAt;

  JsonObject toJson() => {
    'mode': _mode,
    if (startAt case final start?) 'startAt': _instant(start),
    if (endAt case final end?) 'endAt': _instant(end),
  };
}

class EventDetails {
  const EventDetails({
    required this.title,
    required this.category,
    required this.visibility,
    required this.startAt,
    required this.endAt,
    required this.registrationWindow,
    this.description,
    this.imageUrl,
  });

  final String title;
  final String category;
  final EventVisibility visibility;
  final DateTime startAt;
  final DateTime endAt;
  final RegistrationWindow registrationWindow;
  final String? description;
  final String? imageUrl;

  JsonObject toJson() => {
    'title': title,
    'category': category,
    'visibility': visibility.wireValue,
    'startAt': _instant(startAt),
    'endAt': _instant(endAt),
    'registrationWindow': registrationWindow.toJson(),
    'description': description,
    'imageUrl': imageUrl,
  };
}

class TicketTypeDetails {
  const TicketTypeDetails({
    required this.name,
    required this.description,
    required this.price,
    required this.maxPerOrder,
    required this.salesStartAt,
    required this.salesEndAt,
  });

  final String name;
  final String description;

  /// KZT. A decimal string preserves the exact amount, e.g. '5000.00'.
  final String price;
  final int maxPerOrder;
  final DateTime salesStartAt;
  final DateTime salesEndAt;

  JsonObject toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'maxPerOrder': maxPerOrder,
    'salesStartAt': _instant(salesStartAt),
    'salesEndAt': _instant(salesEndAt),
  };
}

class CheckoutSelection {
  const CheckoutSelection({
    required this.ticketTypeId,
    required this.attendeeEmails,
    this.seats = const [],
  });

  final String ticketTypeId;

  /// One email per ticket. For assigned seating, use the same order as [seats].
  final List<String> attendeeEmails;

  /// Seat UUIDs for assigned seating. Leave empty for general admission.
  final List<String> seats;

  JsonObject toJson() => {
    'ticketTypeId': ticketTypeId,
    'attendeeEmails': attendeeEmails,
    'seats': seats,
  };
}

class HalykPaymentSession {
  HalykPaymentSession.fromJson(JsonObject json)
    : auth = json['auth'] as JsonObject,
      scriptUrl = json['scriptUrl'] as String,
      paymentObject = json['paymentObject'] as JsonObject;

  final JsonObject auth;
  final String scriptUrl;
  final JsonObject paymentObject;
}

class UserPage {
  const UserPage({
    required this.items,
    required this.totalCount,
    required this.linkHeader,
  });

  final List<JsonObject> items;
  final int? totalCount;
  final String? linkHeader;
}

/// REST client for the BiletFlow backend. Uses Dio 5.
///
/// Supply a Dio instance whose baseUrl is the server root, for example
/// http://10.0.2.2:8080 on the Android emulator. The service adds /api.
/// Configure that instance to send Authorization: Bearer <JWT> on requests
/// after signing in. Token storage and state belong to the calling app.
///
/// JSON views use the backend's field names. HTTP and transport failures
/// throw a [BiletFlowException] subtype. Catch specific types for UI actions
/// and [BiletFlowException] for remaining API errors. On signup, handle
/// [EmailAlreadyUsedException] or use [BiletFlowException.fieldErrors]
/// to highlight invalid fields.
class BiletFlowService {
  BiletFlowService(this._dio);

  final Dio _dio;

  // Account and staff directory

  /// Returns the JWT from the backend's id_token field.
  Future<String> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final json = await _object(
      'POST',
      '/authenticate',
      body: {'username': email, 'password': password, 'rememberMe': rememberMe},
    );
    return json['id_token'] as String;
  }

  Future<bool> isAuthenticated() async {
    final response = await _request(
      'GET',
      '/authenticate',
      allowUnauthorized: true,
    );
    return response.statusCode == 204;
  }

  Future<void> register({
    required String login,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? langKey,
  }) => _empty(
    'POST',
    '/register',
    body: {
      'login': login,
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'langKey': langKey,
    },
  );

  Future<void> activateAccount(String key) =>
      _empty('GET', '/activate', query: {'key': key});

  Future<JsonObject> getAccount() => _object('GET', '/account');

  /// Supply the current values for any profile fields you want to retain.
  Future<void> updateAccount({
    required String email,
    required String langKey,
    String? firstName,
    String? lastName,
    String? imageUrl,
  }) => _empty(
    'POST',
    '/account',
    body: {
      'email': email,
      'langKey': langKey,
      'firstName': firstName,
      'lastName': lastName,
      'imageUrl': imageUrl,
    },
  );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _empty(
    'POST',
    '/account/change-password',
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  Future<void> requestPasswordReset(String email) =>
      _empty('POST', '/account/reset-password/init', body: {'email': email});

  Future<void> finishPasswordReset({
    required String key,
    required String newPassword,
  }) => _empty(
    'POST',
    '/account/reset-password/finish',
    body: {'key': key, 'newPassword': newPassword},
  );

  Future<UserPage> listUsers({
    int page = 0,
    int size = 20,
    List<String> sort = const [],
  }) => _userPage('/users', page: page, size: size, sort: sort);

  Future<List<JsonObject>> searchUsers(String query) =>
      _list('/users/_search/${_segment(query)}');

  // Event discovery and management

  Future<List<JsonObject>> listPublicEvents() => _list('/events');

  Future<JsonObject> getPublicEvent(String eventId) =>
      _object('GET', _event(eventId));

  Future<List<JsonObject>> listMyEvents() => _list('/events/mine');

  Future<List<JsonObject>> listAssignedCheckInEvents() =>
      _list('/events/assigned-for-check-in');

  Future<JsonObject> getManagedEvent(String eventId) =>
      _object('GET', '${_event(eventId)}/manage');

  /// Returns the new event UUID.
  Future<String> createEvent(EventDetails details) =>
      _create('/events', details.toJson());

  Future<void> updateEvent(String eventId, EventDetails details) =>
      _empty('PUT', _event(eventId), body: details.toJson());

  Future<void> publishEvent(String eventId) =>
      _empty('POST', '${_event(eventId)}/publish');

  Future<void> unpublishEvent(String eventId) =>
      _empty('POST', '${_event(eventId)}/unpublish');

  Future<void> cancelEvent(String eventId) =>
      _empty('POST', '${_event(eventId)}/cancel');

  /// Returns the UUID of the new draft.
  Future<String> duplicateEvent(
    String eventId, {
    required DateTime startAt,
    required DateTime endAt,
    required RegistrationWindow registrationWindow,
  }) => _create('${_event(eventId)}/duplicate', {
    'startAt': _instant(startAt),
    'endAt': _instant(endAt),
    'registrationWindow': registrationWindow.toJson(),
  });

  Future<List<JsonObject>> listVenueLayouts() => _list('/venue-layouts');

  Future<JsonObject> getVenueLayout(String layoutId) =>
      _object('GET', '/venue-layouts/${_segment(layoutId)}');

  /// Set [venueLayoutId] for assigned seating. Omit it for general admission.
  Future<void> attachVenue(
    String eventId, {
    required String name,
    required String address,
    required int capacity,
    String? venueLayoutId,
  }) => _empty(
    'POST',
    '${_event(eventId)}/venue',
    body: {
      'name': name,
      'address': address,
      'capacity': capacity,
      'seatingMode': venueLayoutId == null
          ? 'GENERAL_ADMISSION'
          : 'ASSIGNED_SEATING',
      if (venueLayoutId != null) 'venueLayoutId': venueLayoutId,
    },
  );

  Future<void> assignEventAdmin(String eventId, int staffUserId) => _empty(
    'POST',
    '${_event(eventId)}/staff',
    body: {'staffUserId': staffUserId, 'role': 'EVENT_ADMIN'},
  );

  Future<void> removeEventStaff(String eventId, int staffUserId) =>
      _empty('DELETE', '${_event(eventId)}/staff/$staffUserId');

  // Inventory and ticket types

  Future<JsonObject> getEventInventory(String eventId) =>
      _object('GET', '${_event(eventId)}/inventory');

  Future<List<JsonObject>> getGeneralAdmissionAvailability(String eventId) =>
      _list('${_event(eventId)}/availability');

  Future<List<JsonObject>> getSeatMap(String eventId) =>
      _list('${_event(eventId)}/seat-map');

  Future<List<JsonObject>> listPublicTicketTypes(String eventId) =>
      _list('${_event(eventId)}/ticket-types');

  Future<List<JsonObject>> listManagedTicketTypes(String eventId) =>
      _list('${_event(eventId)}/ticket-types/manage');

  Future<String> createGeneralAdmissionTicketType(
    String eventId,
    TicketTypeDetails details, {
    required int capacity,
  }) => _create('${_event(eventId)}/ticket-types/general-admission', {
    ...details.toJson(),
    'capacity': capacity,
  });

  Future<String> createAssignedSeatingTicketType(
    String eventId,
    TicketTypeDetails details, {
    required String priceCategory,
  }) => _create('${_event(eventId)}/ticket-types/assigned-seating', {
    ...details.toJson(),
    'priceCategory': priceCategory,
  });

  Future<void> updateGeneralAdmissionTicketType(
    String ticketTypeId,
    TicketTypeDetails details, {
    required int capacity,
  }) => _empty(
    'PUT',
    '${_ticketType(ticketTypeId)}/general-admission',
    body: {...details.toJson(), 'capacity': capacity},
  );

  /// The backend requires the existing category in the payload and keeps it fixed.
  Future<void> updateAssignedSeatingTicketType(
    String ticketTypeId,
    TicketTypeDetails details, {
    required String priceCategory,
  }) => _empty(
    'PUT',
    '${_ticketType(ticketTypeId)}/assigned-seating',
    body: {...details.toJson(), 'priceCategory': priceCategory},
  );

  Future<void> hideTicketType(String ticketTypeId) =>
      _empty('POST', '${_ticketType(ticketTypeId)}/hide');

  Future<void> unhideTicketType(String ticketTypeId) =>
      _empty('POST', '${_ticketType(ticketTypeId)}/unhide');

  // Checkout and payments

  /// Generate a UUID for each purchase. Reuse it with the same selections
  /// when retrying after a timeout. For paid orders, read paymentId from the
  /// result and call [openPaymentSession].
  Future<JsonObject> createCheckout({
    required String idempotencyKey,
    required String eventId,
    required List<CheckoutSelection> selections,
  }) => _object(
    'POST',
    '/checkouts',
    headers: {'Idempotency-Key': idempotencyKey},
    body: {
      'eventId': eventId,
      'selections': selections.map((selection) => selection.toJson()).toList(),
    },
  );

  Future<List<JsonObject>> listMyCheckouts() => _list('/checkouts');

  Future<JsonObject> getCheckout(String checkoutId) =>
      _object('GET', '/checkouts/${_segment(checkoutId)}');

  Future<JsonObject> cancelCheckout(String checkoutId) =>
      _object('POST', '/checkouts/${_segment(checkoutId)}/cancel');

  /// An organizer can request a full refund. Read refundState with
  /// [getCheckout] to track the result.
  Future<JsonObject> refundCheckout(
    String checkoutId, {
    required String reason,
  }) => _object(
    'POST',
    '/checkouts/${_segment(checkoutId)}/refund',
    body: {'reason': reason},
  );

  Future<JsonObject> getPayment(String paymentId) =>
      _object('GET', '/payments/${_segment(paymentId)}');

  /// Open the Halyk form using scriptUrl and paymentObject. After the form
  /// returns, read backend status via [getCheckout] or [getPayment].
  Future<HalykPaymentSession> openPaymentSession(String paymentId) async {
    final json = await _object(
      'POST',
      '/payments/${_segment(paymentId)}/session',
    );
    return HalykPaymentSession.fromJson(json);
  }

  Future<JsonObject> getPaidSalesActivation(String eventId) =>
      _object('GET', _activation(eventId));

  Future<JsonObject> getPaidSalesActivationChecklist(String eventId) =>
      _object('GET', '${_activation(eventId)}/checklist');

  Future<JsonObject> requestPaidSalesActivation(
    String eventId, {
    required bool acceptSandboxTerms,
    required bool simulateIdentityAndPayoutVerification,
  }) => _object(
    'POST',
    _activation(eventId),
    body: {
      'acceptSandboxTerms': acceptSandboxTerms,
      'simulateIdentityAndPayoutVerification':
          simulateIdentityAndPayoutVerification,
    },
  );

  Future<JsonObject> getMyRevenue() => _object('GET', '/payments/revenue/mine');

  Future<JsonObject> getPayoutBalance() =>
      _object('GET', '/payments/payouts/balance');

  Future<List<JsonObject>> listPayouts({int offset = 0, int limit = 50}) =>
      _list('/payments/payouts', query: {'offset': offset, 'limit': limit});

  Future<JsonObject> getPayout(String payoutId) =>
      _object('GET', '/payments/payouts/${_segment(payoutId)}');

  /// Keep the same request UUID and exact KZT amount when retrying.
  Future<JsonObject> requestPayout({
    required String requestId,
    required String amountKzt,
    required bool acceptSimulation,
  }) => _object(
    'POST',
    '/payments/payouts',
    body: {
      'requestId': requestId,
      'amountKzt': amountKzt,
      'acceptSimulation': acceptSimulation,
    },
  );

  // Issued tickets and staff check-in

  Future<List<JsonObject>> listMyTickets() => _list('/tickets/mine');

  Future<JsonObject> claimTicket(String ticketId) =>
      _object('POST', '/tickets/${_segment(ticketId)}/claim');

  Future<Uint8List> downloadTicketPdf(String ticketId) =>
      _bytes('/tickets/${_segment(ticketId)}/pdf', 'application/pdf');

  Future<Uint8List> downloadTicketQr(String ticketId) =>
      _bytes('/tickets/${_segment(ticketId)}/qr', 'image/png');

  /// Queues delivery to the recorded attendee email.
  Future<void> emailTicket(String ticketId) =>
      _empty('POST', '/tickets/${_segment(ticketId)}/delivery');

  /// [ticketCode] is the UUID encoded in the admission QR.
  Future<JsonObject> validateTicket(String eventId, String ticketCode) =>
      _object('GET', '${_checkInTicket(eventId, ticketCode)}/validation');

  Future<JsonObject> checkInTicket(String eventId, String ticketCode) =>
      _object('POST', _checkInTicket(eventId, ticketCode));

  Future<JsonObject> reverseCheckIn(String eventId, String ticketCode) =>
      _object('POST', '${_checkInTicket(eventId, ticketCode)}/reverse');

  Future<List<JsonObject>> searchEventAttendees(
    String eventId, {
    required String email,
  }) => _list('${_event(eventId)}/check-in/attendees', query: {'email': email});

  Future<JsonObject> getCheckInCounts(String eventId) =>
      _object('GET', '${_event(eventId)}/check-in/counts');

  // Platform administration

  Future<UserPage> listAdminUsers({
    int page = 0,
    int size = 20,
    List<String> sort = const [],
  }) => _userPage('/admin/users', page: page, size: size, sort: sort);

  Future<JsonObject> getAdminUser(String login) =>
      _object('GET', '/admin/users/${_segment(login)}');

  /// Fields follow AdminUserDTO. Supply login and the desired profile fields
  /// and authorities. The backend assigns the ID.
  Future<JsonObject> createAdminUser(JsonObject user) =>
      _object('POST', '/admin/users', body: user);

  /// Supply the full editable AdminUserDTO, including its numeric id.
  Future<JsonObject> updateAdminUser(JsonObject user, {String? login}) =>
      _object(
        'PUT',
        login == null ? '/admin/users' : '/admin/users/${_segment(login)}',
        body: user,
      );

  Future<void> deleteAdminUser(String login) =>
      _empty('DELETE', '/admin/users/${_segment(login)}');

  Future<List<JsonObject>> listAuthorities() => _list('/authorities');

  Future<JsonObject> getAuthority(String name) =>
      _object('GET', '/authorities/${_segment(name)}');

  Future<JsonObject> createAuthority(String name) =>
      _object('POST', '/authorities', body: {'name': name});

  Future<void> deleteAuthority(String name) =>
      _empty('DELETE', '/authorities/${_segment(name)}');

  /// Filters use backend enum values such as SUCCEEDED and TICKET.
  Future<List<JsonObject>> listAdminPayments({
    String? status,
    String? purpose,
    String? eventId,
    int? payerId,
    int offset = 0,
    int limit = 50,
  }) => _list(
    '/payments/admin/payments',
    query: {
      if (status != null) 'status': status,
      if (purpose != null) 'purpose': purpose,
      if (eventId != null) 'eventId': eventId,
      if (payerId != null) 'payerId': payerId,
      'offset': offset,
      'limit': limit,
    },
  );

  /// Activation status values are PENDING, ACTIVE and SUSPENDED.
  Future<List<JsonObject>> listAdminActivations({
    String? status,
    int offset = 0,
    int limit = 50,
  }) => _list(
    '/payments/admin/activations',
    query: {
      if (status != null) 'status': status,
      'offset': offset,
      'limit': limit,
    },
  );

  Future<JsonObject> suspendPaidSales(
    String eventId, {
    required String reason,
  }) => _object(
    'POST',
    '/payments/admin/events/${_segment(eventId)}/paid-sales/suspend',
    body: {'reason': reason},
  );

  Future<JsonObject> getActivationFee() =>
      _object('GET', '/payments/admin/settings/activation-fee');

  Future<JsonObject> updateActivationFee(String amountKzt) => _object(
    'PUT',
    '/payments/admin/settings/activation-fee',
    body: {'amountKzt': amountKzt},
  );

  Future<List<JsonObject>> listPaymentOperationsRequiringReview() =>
      _list('/payments/operations');

  /// Supply the backend OperationResolution value and verified bank evidence.
  Future<void> resolvePaymentOperation(
    String paymentId, {
    required String resolution,
    required String bankSupportReference,
    String? expectedOperationId,
  }) => _empty(
    'POST',
    '/payments/${_segment(paymentId)}/resolve-operation',
    body: {
      'expectedOperationId': expectedOperationId,
      'resolution': resolution,
      'bankSupportReference': bankSupportReference,
    },
  );

  static String _event(String id) => '/events/${_segment(id)}';
  static String _ticketType(String id) => '/ticket-types/${_segment(id)}';
  static String _activation(String eventId) =>
      '/payments/events/${_segment(eventId)}/activation';
  static String _checkInTicket(String eventId, String ticketCode) =>
      '${_event(eventId)}/check-in/tickets/${_segment(ticketCode)}';

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    JsonObject? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    ResponseType responseType = ResponseType.json,
    bool allowUnauthorized = false,
  }) async {
    try {
      return await _dio.request<dynamic>(
        '/api$path',
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: headers,
          contentType: body == null ? null : 'application/json',
          responseType: responseType,
          receiveDataWhenStatusError: true,
          validateStatus: (status) =>
              status != null &&
              ((status >= 200 && status < 300) ||
                  (allowUnauthorized && status == 401)),
        ),
      );
    } on DioException catch (error, stackTrace) {
      // Dio may reject a 401 in an app interceptor even if validateStatus
      // accepts it. The authentication probe still returns false.
      final response = error.response;
      if (allowUnauthorized && response?.statusCode == 401) {
        return response!;
      }
      Error.throwWithStackTrace(_apiError(error, method, path), stackTrace);
    }
  }

  Future<JsonObject> _object(
    String method,
    String path, {
    JsonObject? body,
    Map<String, dynamic>? headers,
  }) async {
    final response = await _request(method, path, body: body, headers: headers);
    return response.data as JsonObject;
  }

  Future<List<JsonObject>> _list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _request('GET', path, query: query);
    return (response.data as List).cast<JsonObject>();
  }

  Future<void> _empty(
    String method,
    String path, {
    JsonObject? body,
    Map<String, dynamic>? query,
  }) async {
    await _request(method, path, body: body, query: query);
  }

  Future<String> _create(String path, JsonObject body) async {
    final json = await _object('POST', path, body: body);
    return json['id'] as String;
  }

  Future<Uint8List> _bytes(String path, String mediaType) async {
    final response = await _request(
      'GET',
      path,
      responseType: ResponseType.bytes,
      headers: {'Accept': '$mediaType, application/problem+json'},
    );
    final data = response.data as List<int>;
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  Future<UserPage> _userPage(
    String path, {
    required int page,
    required int size,
    required List<String> sort,
  }) async {
    final response = await _request(
      'GET',
      path,
      query: {'page': page, 'size': size, if (sort.isNotEmpty) 'sort': sort},
    );
    return UserPage(
      items: (response.data as List).cast<JsonObject>(),
      totalCount: int.tryParse(response.headers.value('x-total-count') ?? ''),
      linkHeader: response.headers['link']?.join(', '),
    );
  }
}

/// A failure returned by the BiletFlow API or its HTTP transport.
///
/// [detail] and [problem] are server diagnostics. Prefer localized UI text
/// chosen by exception type, and use [fieldErrors] for form feedback.
class BiletFlowException implements Exception {
  const BiletFlowException(this.cause, this.problem);

  final DioException cause;
  final JsonObject problem;

  int? get statusCode => cause.response?.statusCode;
  String? get detail => _text(problem['detail']);
  String? get title => _text(problem['title']);
  String? get problemType => _text(problem['type']);
  String? get errorCode =>
      _text(problem['errorKey']) ?? _text(problem['message']);
  String? get retryAfter => cause.response?.headers['retry-after']?.join(', ');

  List<ApiFieldError> get fieldErrors => _fieldErrors(problem);

  @override
  String toString() =>
      statusCode == null ? '$runtimeType' : '$runtimeType (HTTP $statusCode)';
}

class ApiFieldError {
  const ApiFieldError(this.field, this.message);

  final String field;
  final String message;
}

class RequestValidationException extends BiletFlowException {
  const RequestValidationException(super.cause, super.problem);

  @override
  String toString() {
    final summary = super.toString();
    final errors = fieldErrors;
    if (errors.isEmpty) return summary;

    final messagesByField = <String, Set<String>>{};
    for (final error in errors) {
      (messagesByField[error.field] ??= <String>{}).add(error.message);
    }
    final fields = messagesByField.entries.map(
      (entry) => '${entry.key}: ${entry.value.join(', ')}',
    );
    return '$summary [${fields.join(' | ')}]';
  }
}

class AuthenticationRequiredException extends BiletFlowException {
  const AuthenticationRequiredException(super.cause, super.problem);
}

class PermissionDeniedException extends BiletFlowException {
  const PermissionDeniedException(super.cause, super.problem);
}

class ResourceNotFoundException extends BiletFlowException {
  const ResourceNotFoundException(super.cause, super.problem);
}

class OperationConflictException extends BiletFlowException {
  const OperationConflictException(super.cause, super.problem);
}

class RateLimitedException extends BiletFlowException {
  const RateLimitedException(super.cause, super.problem);
}

class ServerUnavailableException extends BiletFlowException {
  const ServerUnavailableException(super.cause, super.problem);
}

class ServerFailureException extends BiletFlowException {
  const ServerFailureException(super.cause, super.problem);
}

class UnexpectedHttpException extends BiletFlowException {
  const UnexpectedHttpException(super.cause, super.problem);
}

class TransportException extends BiletFlowException {
  const TransportException(super.cause, super.problem);
}

class InvalidApiResponseException extends BiletFlowException {
  const InvalidApiResponseException(super.cause, super.problem);
}

class EmailAlreadyUsedException extends RequestValidationException {
  const EmailAlreadyUsedException(super.cause, super.problem);
}

class LoginAlreadyUsedException extends RequestValidationException {
  const LoginAlreadyUsedException(super.cause, super.problem);
}

/// A new password or a sign-in password failed request validation.
/// The current backend requires nonblank passwords of 4–100 characters.
class PasswordRequirementsException extends RequestValidationException {
  const PasswordRequirementsException(super.cause, super.problem);
}

/// The change-password request supplied an incorrect current password.
class IncorrectCurrentPasswordException extends RequestValidationException {
  const IncorrectCurrentPasswordException(super.cause, super.problem);
}

class InvalidActivationKeyException extends RequestValidationException {
  const InvalidActivationKeyException(super.cause, super.problem);
}

class InvalidPasswordResetKeyException extends RequestValidationException {
  const InvalidPasswordResetKeyException(super.cause, super.problem);
}

class AuthorityAlreadyExistsException extends RequestValidationException {
  const AuthorityAlreadyExistsException(super.cause, super.problem);
}

class NewUserAlreadyHasIdException extends RequestValidationException {
  const NewUserAlreadyHasIdException(super.cause, super.problem);
}

class InvalidUserSearchException extends RequestValidationException {
  const InvalidUserSearchException(super.cause, super.problem);
}

class InvalidCheckoutSelectionException extends RequestValidationException {
  const InvalidCheckoutSelectionException(super.cause, super.problem);
}

class InvalidEventDetailsException extends RequestValidationException {
  const InvalidEventDetailsException(super.cause, super.problem);
}

class InvalidVenueConfigurationException extends RequestValidationException {
  const InvalidVenueConfigurationException(super.cause, super.problem);
}

class InvalidTicketTypeDetailsException extends RequestValidationException {
  const InvalidTicketTypeDetailsException(super.cause, super.problem);
}

class AttendeeSearchTooShortException extends RequestValidationException {
  const AttendeeSearchTooShortException(super.cause, super.problem);
}

class InvalidPaginationException extends RequestValidationException {
  const InvalidPaginationException(super.cause, super.problem);
}

class PaidSalesTermsRequiredException extends RequestValidationException {
  const PaidSalesTermsRequiredException(super.cause, super.problem);
}

class PayoutTermsRequiredException extends RequestValidationException {
  const PayoutTermsRequiredException(super.cause, super.problem);
}

class InvalidPayoutAmountException extends RequestValidationException {
  const InvalidPayoutAmountException(super.cause, super.problem);
}

class InvalidCredentialsException extends AuthenticationRequiredException {
  const InvalidCredentialsException(super.cause, super.problem);
}

class AccountNotActivatedException extends AuthenticationRequiredException {
  const AccountNotActivatedException(super.cause, super.problem);
}

class TicketEmailMismatchException extends PermissionDeniedException {
  const TicketEmailMismatchException(super.cause, super.problem);
}

class VerifiedEmailRequiredException extends PermissionDeniedException {
  const VerifiedEmailRequiredException(super.cause, super.problem);
}

class EventNotFoundException extends ResourceNotFoundException {
  const EventNotFoundException(super.cause, super.problem);
}

class VenueLayoutNotFoundException extends ResourceNotFoundException {
  const VenueLayoutNotFoundException(super.cause, super.problem);
}

class TicketNotFoundException extends ResourceNotFoundException {
  const TicketNotFoundException(super.cause, super.problem);
}

class TicketTypeNotFoundException extends ResourceNotFoundException {
  const TicketTypeNotFoundException(super.cause, super.problem);
}

class EventInventoryNotFoundException extends ResourceNotFoundException {
  const EventInventoryNotFoundException(super.cause, super.problem);
}

class CheckoutNotFoundException extends ResourceNotFoundException {
  const CheckoutNotFoundException(super.cause, super.problem);
}

class PaymentNotFoundException extends ResourceNotFoundException {
  const PaymentNotFoundException(super.cause, super.problem);
}

class PaidSalesActivationNotFoundException extends ResourceNotFoundException {
  const PaidSalesActivationNotFoundException(super.cause, super.problem);
}

class PayoutNotFoundException extends ResourceNotFoundException {
  const PayoutNotFoundException(super.cause, super.problem);
}

class UserNotFoundException extends ResourceNotFoundException {
  const UserNotFoundException(super.cause, super.problem);
}

class AuthorityNotFoundException extends ResourceNotFoundException {
  const AuthorityNotFoundException(super.cause, super.problem);
}

class ConcurrentUpdateException extends OperationConflictException {
  const ConcurrentUpdateException(super.cause, super.problem);
}

class EventStateException extends OperationConflictException {
  const EventStateException(super.cause, super.problem);
}

class InventoryModeMismatchException extends OperationConflictException {
  const InventoryModeMismatchException(super.cause, super.problem);
}

class TicketTypeStateException extends OperationConflictException {
  const TicketTypeStateException(super.cause, super.problem);
}

class TicketUnavailableException extends OperationConflictException {
  const TicketUnavailableException(super.cause, super.problem);
}

class TicketOrderLimitException extends OperationConflictException {
  const TicketOrderLimitException(super.cause, super.problem);
}

class CheckoutStateException extends OperationConflictException {
  const CheckoutStateException(super.cause, super.problem);
}

class RefundNotAllowedException extends OperationConflictException {
  const RefundNotAllowedException(super.cause, super.problem);
}

class IdempotencyConflictException extends OperationConflictException {
  const IdempotencyConflictException(super.cause, super.problem);
}

class RegistrationClosedException extends OperationConflictException {
  const RegistrationClosedException(super.cause, super.problem);
}

class PaidSalesInactiveException extends OperationConflictException {
  const PaidSalesInactiveException(super.cause, super.problem);
}

class PaidSalesActivationStateException extends OperationConflictException {
  const PaidSalesActivationStateException(super.cause, super.problem);
}

class PaymentStateException extends OperationConflictException {
  const PaymentStateException(super.cause, super.problem);
}

class PaymentSessionUnavailableException extends OperationConflictException {
  const PaymentSessionUnavailableException(super.cause, super.problem);
}

class PaymentOperationChangedException extends OperationConflictException {
  const PaymentOperationChangedException(super.cause, super.problem);
}

class PayoutStateException extends OperationConflictException {
  const PayoutStateException(super.cause, super.problem);
}

class InsufficientPayoutBalanceException extends OperationConflictException {
  const InsufficientPayoutBalanceException(super.cause, super.problem);
}

class PayoutBlockedException extends OperationConflictException {
  const PayoutBlockedException(super.cause, super.problem);
}

class TicketAlreadyClaimedException extends OperationConflictException {
  const TicketAlreadyClaimedException(super.cause, super.problem);
}

class CheckInStateException extends OperationConflictException {
  const CheckInStateException(super.cause, super.problem);
}

class TicketForDifferentEventException extends OperationConflictException {
  const TicketForDifferentEventException(super.cause, super.problem);
}

class TicketQrUnavailableException extends OperationConflictException {
  const TicketQrUnavailableException(super.cause, super.problem);
}

class TicketDocumentRenderingException extends OperationConflictException {
  const TicketDocumentRenderingException(super.cause, super.problem);
}

class TicketDeliveryUnavailableException extends OperationConflictException {
  const TicketDeliveryUnavailableException(super.cause, super.problem);
}

/// Wait at least one minute between completed ticket email deliveries.
class TicketDeliveryCooldownException extends OperationConflictException {
  const TicketDeliveryCooldownException(super.cause, super.problem);
}

class PaymentProviderUnavailableException extends ServerUnavailableException {
  const PaymentProviderUnavailableException(super.cause, super.problem);
}

class ConnectionFailedException extends TransportException {
  const ConnectionFailedException(super.cause, super.problem);
}

class RequestTimeoutException extends TransportException {
  const RequestTimeoutException(super.cause, super.problem);
}

class RequestCancelledException extends TransportException {
  const RequestCancelledException(super.cause, super.problem);
}

class InvalidServerCertificateException extends TransportException {
  const InvalidServerCertificateException(super.cause, super.problem);
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

JsonObject _readProblem(Object? body) {
  try {
    // PDF and QR requests ask Dio for bytes even on HTTP errors.
    if (body is List<int>) body = utf8.decode(body);
    if (body is String) body = jsonDecode(body);
  } on FormatException {
    // A proxy or security filter may send an empty or non-JSON error body.
    return const {};
  }
  return body is JsonObject ? Map.unmodifiable(body) : const {};
}

List<ApiFieldError> _fieldErrors(JsonObject problem) {
  final entries = problem['fieldErrors'];
  if (entries is List) {
    return List.unmodifiable([
      for (final entry in entries)
        if (entry is Map &&
            entry['field'] is String &&
            entry['message'] is String)
          ApiFieldError(entry['field'] as String, entry['message'] as String),
    ]);
  }

  // Event, ticket, and payment advice sends only the first invalid field
  // as a "field: message" detail.
  if (problem['title'] == 'Invalid request') {
    final detail = _text(problem['detail']) ?? '';
    final match = RegExp(
      r'^([a-z][A-Za-z0-9_.]*(?:\[\d+\][A-Za-z0-9_.]*)*): (.+)$',
    ).firstMatch(detail);
    if (match != null) {
      return [ApiFieldError(match.group(1)!, match.group(2)!)];
    }
  }
  return const [];
}

BiletFlowException _apiError(DioException cause, String method, String path) {
  final response = cause.response;
  final problem = _readProblem(response?.data);
  final status = response?.statusCode;
  if (status == null || (status >= 200 && status < 300)) {
    return switch (cause.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => RequestTimeoutException(
        cause,
        problem,
      ),
      DioExceptionType.connectionError => ConnectionFailedException(
        cause,
        problem,
      ),
      DioExceptionType.badCertificate => InvalidServerCertificateException(
        cause,
        problem,
      ),
      DioExceptionType.cancel => RequestCancelledException(cause, problem),
      _ when cause.error is FormatException => InvalidApiResponseException(
        cause,
        problem,
      ),
      _ => TransportException(cause, problem),
    };
  }

  final code = _text(problem['errorKey']) ?? _text(problem['message']);
  final type = _text(problem['type']);
  final detail = _text(problem['detail']) ?? '';
  final title = _text(problem['title']);

  return switch (status) {
    400 || 422 => _invalidRequest(cause, problem, path, code, type, detail),
    401 when code == 'usernotactivated' || title == 'User Not Activated' =>
      AccountNotActivatedException(cause, problem),
    401 when method == 'POST' && path == '/authenticate' =>
      InvalidCredentialsException(cause, problem),
    401 => AuthenticationRequiredException(cause, problem),
    403
        when detail ==
            'Ticket attendee email does not match the authenticated user' =>
      TicketEmailMismatchException(cause, problem),
    403 when detail == 'Authenticated user does not have a verified email' =>
      VerifiedEmailRequiredException(cause, problem),
    403 => PermissionDeniedException(cause, problem),
    404 => _notFound(cause, problem, method, path, detail),
    409 when code == 'error.concurrencyFailure' => ConcurrentUpdateException(
      cause,
      problem,
    ),
    409 => _conflict(cause, problem, path, detail),
    429 => RateLimitedException(cause, problem),
    503 when title == 'Payment provider unavailable' =>
      PaymentProviderUnavailableException(cause, problem),
    502 || 503 || 504 => ServerUnavailableException(cause, problem),
    >= 500 => ServerFailureException(cause, problem),
    _ => UnexpectedHttpException(cause, problem),
  };
}

BiletFlowException _invalidRequest(
  DioException cause,
  JsonObject problem,
  String path,
  String? code,
  String? type,
  String detail,
) {
  const jhipsterProblem = 'https://www.jhipster.tech/problem';
  if (code == 'error.emailexists' ||
      type == '$jhipsterProblem/email-already-used') {
    return EmailAlreadyUsedException(cause, problem);
  }
  if (code == 'error.userexists' ||
      type == '$jhipsterProblem/login-already-used') {
    return LoginAlreadyUsedException(cause, problem);
  }
  if (type == '$jhipsterProblem/invalid-password') {
    return IncorrectCurrentPasswordException(cause, problem);
  }
  if (code == 'error.idexists') {
    if (problem['params'] == 'adminAuthority' || path == '/authorities') {
      return AuthorityAlreadyExistsException(cause, problem);
    }
    if (problem['params'] == 'userManagement' || path == '/admin/users') {
      return NewUserAlreadyHasIdException(cause, problem);
    }
  }
  if (code == 'error.querySyntaxError') {
    return InvalidUserSearchException(cause, problem);
  }

  final errors = _fieldErrors(problem);
  if (errors.isNotEmpty &&
      errors.every(
        (error) => error.field == 'password' || error.field == 'newPassword',
      )) {
    return PasswordRequirementsException(cause, problem);
  }
  if (errors.any(
    (error) =>
        error.field == 'acceptSandboxTerms' ||
        error.field == 'simulateIdentityAndPayoutVerification',
  )) {
    return PaidSalesTermsRequiredException(cause, problem);
  }
  if (path == '/payments/payouts') {
    if (errors.any((error) => error.field == 'acceptSimulation') ||
        detail ==
            'Accept the simulated payout terms; no real money will move') {
      return PayoutTermsRequiredException(cause, problem);
    }
    if (errors.any((error) => error.field == 'amountKzt') ||
        detail ==
            'Payout amount must be positive KZT with at most two decimal places') {
      return InvalidPayoutAmountException(cause, problem);
    }
  }

  return switch (detail) {
    'No user was found for this activation key' =>
      InvalidActivationKeyException(cause, problem),
    'No user was found for this reset key' => InvalidPasswordResetKeyException(
      cause,
      problem,
    ),
    'Search requires at least three characters' =>
      AttendeeSearchTooShortException(cause, problem),
    'Invalid payout pagination' ||
    'Invalid pagination' => InvalidPaginationException(cause, problem),
    _
        when path == '/checkouts' &&
            (errors.isNotEmpty ||
                detail == 'Combine selections for each ticket type' ||
                detail == 'Supply one distinct seat per attendee' ||
                detail == 'Cannot mix seating modes' ||
                detail == 'Ticket type belongs to a different event' ||
                detail == 'Invalid attendee count' ||
                detail == 'Checkout requires 1 to 100 tickets' ||
                detail == 'Supply 1 to 30 ticket selections' ||
                detail.startsWith('Seat does not exist in event inventory:')) =>
      InvalidCheckoutSelectionException(cause, problem),
    _ when path.endsWith('/venue') && path.startsWith('/events/') =>
      InvalidVenueConfigurationException(cause, problem),
    _
        when path.startsWith('/events') &&
            (path == '/events' ||
                path.endsWith('/duplicate') ||
                (path.split('/').length == 3 && errors.isNotEmpty)) =>
      InvalidEventDetailsException(cause, problem),
    _
        when path.endsWith('/general-admission') ||
            path.endsWith('/assigned-seating') =>
      InvalidTicketTypeDetailsException(cause, problem),
    _ => RequestValidationException(cause, problem),
  };
}

BiletFlowException _notFound(
  DioException cause,
  JsonObject problem,
  String method,
  String path,
  String detail,
) => switch (detail) {
  _ when detail.startsWith('SocialEvent not found with identifier:') =>
    EventNotFoundException(cause, problem),
  _ when detail.startsWith('VenueLayout not found with identifier:') =>
    VenueLayoutNotFoundException(cause, problem),
  _
      when detail == 'Ticket not found for supplied ticket code' ||
          detail.startsWith('Ticket not found:') =>
    TicketNotFoundException(cause, problem),
  _
      when detail.startsWith('TicketType not found:') ||
          detail == 'Ticket type not found' =>
    TicketTypeNotFoundException(cause, problem),
  _ when detail.startsWith('EventInventory not found for event:') =>
    EventInventoryNotFoundException(cause, problem),
  'Checkout not found' => CheckoutNotFoundException(cause, problem),
  'Payment not found' => PaymentNotFoundException(cause, problem),
  'Activation not found' => PaidSalesActivationNotFoundException(
    cause,
    problem,
  ),
  'Payout not found' => PayoutNotFoundException(cause, problem),
  _ when method == 'GET' && path.startsWith('/admin/users/') =>
    UserNotFoundException(cause, problem),
  _ when method == 'GET' && path.startsWith('/authorities/') =>
    AuthorityNotFoundException(cause, problem),
  _ => ResourceNotFoundException(cause, problem),
};

BiletFlowException _conflict(
  DioException cause,
  JsonObject problem,
  String path,
  String detail,
) => switch (detail) {
  'Idempotency-Key was used for a different checkout' ||
  'Payout request ID was already used for a different amount' ||
  'Payment idempotency conflict' => IdempotencyConflictException(
    cause,
    problem,
  ),
  'Event is not accepting registrations' ||
  'Event is not accepting purchases' => RegistrationClosedException(
    cause,
    problem,
  ),
  'Paid sales are not activated' ||
  'Paid sales are not active' => PaidSalesInactiveException(cause, problem),
  'Requested quantity exceeds ticket type per-order limit' ||
  'Selected seat count exceeds ticket type per-order limit' =>
    TicketOrderLimitException(cause, problem),
  'Ticket type is not currently purchasable' ||
  'Insufficient inventory available to reserve' => TicketUnavailableException(
    cause,
    problem,
  ),
  _ when detail.startsWith('Seat is currently held or sold:') =>
    TicketUnavailableException(cause, problem),
  'Payment is not available for a bank session' =>
    PaymentSessionUnavailableException(cause, problem),
  'Operation changed; reload before resolving' =>
    PaymentOperationChangedException(cause, problem),
  'Payout exceeds the available organizer balance' =>
    InsufficientPayoutBalanceException(cause, problem),
  'Payouts are blocked while a ticket payment or refund requires reconciliation' =>
    PayoutBlockedException(cause, problem),
  'Ticket is already linked to another user' => TicketAlreadyClaimedException(
    cause,
    problem,
  ),
  'This ticket has no usable admission QR code' => TicketQrUnavailableException(
    cause,
    problem,
  ),
  'Ticket QR could not be rendered' ||
  'Ticket PDF could not be rendered' ||
  'Bundled ticket font is missing' => TicketDocumentRenderingException(
    cause,
    problem,
  ),
  'Ticket is not valid for the selected event' =>
    TicketForDifferentEventException(cause, problem),
  'Wait at least one minute before requesting another email' =>
    TicketDeliveryCooldownException(cause, problem),
  'Only a valid ticket for a non-cancelled event can be emailed' =>
    TicketDeliveryUnavailableException(cause, problem),
  'Seat availability is only defined for assigned-seating events' ||
  'Operation requires general-admission inventory' ||
  'Operation requires assigned-seating inventory' =>
    InventoryModeMismatchException(cause, problem),
  _
      when detail.startsWith('Event uses assigned seating;') ||
          detail.startsWith('Event uses general admission;') ||
          detail.startsWith('Assigned-seating ticket type cannot be updated') ||
          detail.startsWith(
            'General-admission ticket type cannot be updated',
          ) ||
          detail.startsWith(
            'Ticket type belongs to an event that does not use',
          ) =>
    InventoryModeMismatchException(cause, problem),
  _ when path.endsWith('/refund') && path.startsWith('/checkouts/') =>
    RefundNotAllowedException(cause, problem),
  _ when path == '/checkouts' || path.startsWith('/checkouts/') =>
    CheckoutStateException(cause, problem),
  _ when path.startsWith('/payments/payouts') => PayoutStateException(
    cause,
    problem,
  ),
  _
      when path.startsWith('/payments/') &&
          (path.endsWith('/activation') ||
              path.endsWith('/paid-sales/suspend')) =>
    PaidSalesActivationStateException(cause, problem),
  _ when path.startsWith('/payments/') => PaymentStateException(cause, problem),
  _ when path.contains('/check-in/') => CheckInStateException(cause, problem),
  _ when path.contains('/ticket-types/') => TicketTypeStateException(
    cause,
    problem,
  ),
  _ when path.startsWith('/events/') => EventStateException(cause, problem),
  _ => OperationConflictException(cause, problem),
};
