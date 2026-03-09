class StoryPage {
  final String imagePath;
  final String text;

  const StoryPage({
    required this.imagePath,
    required this.text,
  });

  factory StoryPage.fromJson(Map<String, dynamic> json) {
    return StoryPage(
      imagePath: json['image'] as String,
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'image': imagePath,
        'text': text,
      };
}
