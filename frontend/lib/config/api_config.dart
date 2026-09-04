const String _rawApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://168-107-29-144.sslip.io/api/v1',
);

const String apiBaseUrl = _rawApiBaseUrl == ''
    ? 'https://168-107-29-144.sslip.io/api/v1'
    : _rawApiBaseUrl;

const String _rawImageBaseUrl = String.fromEnvironment(
  'IMAGE_BASE_URL',
  defaultValue: 'https://168-107-29-144.sslip.io',
);

const String imageBaseUrl = _rawImageBaseUrl == ''
    ? 'https://168-107-29-144.sslip.io'
    : _rawImageBaseUrl;
