class AppFailure implements Exception {
  final String message;

  AppFailure(this.message);

  @override
  String toString() => message;
}