import 'drawing_objects.dart';

class Slide {
  String id;
  String background;
  List<dynamic> objects; 

  Slide({required this.id, this.background = 'White', this.objects = const []});

  factory Slide.fromJson(Map<String, dynamic> json) {
    List<dynamic> parsedObjects = (json['Objects'] as List<dynamic>).map((
      objJson,
    ) {
      final type = objJson['type'] as String;
      if (type == 'pen') {
        return PenObject.fromJson(objJson as Map<String, dynamic>);
      } else {
        return DrawingObject.fromJson(objJson as Map<String, dynamic>);
      }
    }).toList();

    return Slide(
      id: json['Id'] as String,
      background: json['background'] as String? ?? 'White',
      objects: parsedObjects,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'background': background,
      'Objects': objects.map((obj) {
        if (obj is PenObject) return obj.toJson();
        if (obj is DrawingObject) return obj.toJson();
        return {}; 
      }).toList(),
    };
  }
  Slide copyWith({
        String? id,
        String? background,
        List<dynamic>? objects,
    }) {
        return Slide(
            id: id ?? this.id,
            background: background ?? this.background,
            objects: objects ?? List<dynamic>.from(this.objects),
        );
    }
}

class WhiteBoard {
  String id;
  String title;
  String creationDate;
  List<Slide> slides;
  int currentSlideIndex;

  WhiteBoard({
    required this.id,
    required this.title,
    required this.creationDate,
    this.slides = const [],
    this.currentSlideIndex = 0,
  });

  factory WhiteBoard.fromJson(Map<String, dynamic> json) {
    return WhiteBoard(
      id: json['id'] as String,
      title: json['title'] as String,
      creationDate: json['creationDate'] as String,
      slides: (json['slides'] as List<dynamic>)
          .map((s) => Slide.fromJson(s as Map<String, dynamic>))
          .toList(),
      currentSlideIndex: json['currentSlideIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'creationDate': creationDate,
      'slides': slides.map((s) => s.toJson()).toList(),
      'currentSlideIndex': currentSlideIndex,
    };
  }

  WhiteBoard copyWith({
    String? id,
    String? title,
    String? creationDate,
    List<Slide>? slides,
    int? currentSlideIndex,
  }) {
    return WhiteBoard(
      id: id ?? this.id,
      title: title ?? this.title,
      creationDate: creationDate ?? this.creationDate,
      slides: slides ?? List<Slide>.from(this.slides),
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
    );
  }
}
