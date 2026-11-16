import 'dart:io';

/// Whether [error] is a broken or refused connection.
bool isSocketException(Object error) => error is SocketException;
