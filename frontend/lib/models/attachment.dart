class Attachment {
  const Attachment({
    required this.url,
    required this.originalFilename,
    this.contentType,
    this.size,
    required this.isImage,
  });

  final String url;
  final String originalFilename;
  final String? contentType;
  final int? size;
  final bool isImage;

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    url: json['url'] as String,
    originalFilename: json['originalFilename'] as String? ?? '첨부파일',
    contentType: json['contentType'] as String?,
    size: (json['size'] as num?)?.toInt(),
    isImage: json['image'] as bool? ?? false,
  );
}
