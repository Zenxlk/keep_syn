class StandardResponse {
  final String status;
  final String message;
  final Map<String, dynamic>? data;

  StandardResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory StandardResponse.fromJson(Map<String, dynamic> json) {
    return StandardResponse(
      status: json['status'] ?? 'ERROR',
      message: json['message'] ?? 'Error desconocido',
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  bool get isOk => status == 'OK';
}