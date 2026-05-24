class WordPair {
  final String id;
  final String word;
  final String translation;
  final String? note;

  const WordPair({
    required this.id,
    required this.word,
    required this.translation,
    this.note,
  });

  factory WordPair.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String;
    final translation = json['translation'] as String;
    return WordPair(
      id: json['id'] as String? ?? '${word}_$translation',
      word: word,
      translation: translation,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'translation': translation,
        if (note != null) 'note': note,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WordPair && id == other.id;

  @override
  int get hashCode => id.hashCode;
}