enum DocumentStatus { processing, extracted, verified, extractionFailed, unknown }

DocumentStatus documentStatusFromApi(String? raw) {
  return switch (raw) {
    'processing' => DocumentStatus.processing,
    'extracted' => DocumentStatus.extracted,
    'verified' => DocumentStatus.verified,
    'extraction_failed' => DocumentStatus.extractionFailed,
    _ => DocumentStatus.unknown,
  };
}
