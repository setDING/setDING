/// Whether [error] is a broken or refused connection. Browsers report
/// network errors as `ClientException`s of `package:http` only.
bool isSocketException(Object error) => false;
