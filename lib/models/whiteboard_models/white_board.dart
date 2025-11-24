import 'drawing_objects.dart';

class Slide {
  String id;
  String background;
  List<dynamic> objects;

  Slide({required this.id, this.background = 'White', this.objects = const []});

  factory Slide.fromJson(Map<String, dynamic> json) {
    var rawObjects = json['objects'];
  if (rawObjects == null || rawObjects is! List) {
    rawObjects = [];
  }
        List<dynamic> parsedObjects = (rawObjects).map((objJson) {
      // Ensure objJson is cast correctly
      final map = objJson as Map<String, dynamic>; 
      final type = map['type'] as String?;
      
      if (type == null) return null;
      
      if (type == 'pen') {
        return PenObject.fromJson(map);
      } else if (type == "eraser") {
        return null;
      } else {
        return DrawingObject.fromJson(map);
      }
    }).where((element) => element != null).toList();
    
    return Slide(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
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

  Slide copyWith({String? id, String? background, List<dynamic>? objects}) {
    return Slide(
      id: id ?? this.id,
      background: background ?? this.background,
      objects: objects ?? List<dynamic>.from(this.objects),
    );
  }
}

// lib/models/whiteboard_models/white_board.dart

class WhiteBoard {
  String id;
  String title;
  String creationDate;
  List<Slide> slides;
  int currentSlideIndex;
  
  // New flag to track if this board is saved to the backend
  bool isSynced; 

  WhiteBoard({
    required this.id,
    required this.title,
    required this.creationDate,
    this.slides = const [],
    this.currentSlideIndex = 0,
    this.isSynced = false, // Default to false for offline creation
  });

  factory WhiteBoard.fromJson(Map<String, dynamic> json) {
    // Backend sends '_id', Local storage might send 'id'
    String idVal = json['_id'] ?? json['id'] ?? '';
    
    return WhiteBoard(
      id: idVal,
      title: json['title'] ?? 'Untitled',
      creationDate: json['creationDate'] ?? '',
      slides: json['slides'] != null 
          ? (json['slides'] as List<dynamic>)
              .map((s) => Slide.fromJson(s as Map<String, dynamic>))
              .toList()
          : [],
      currentSlideIndex: json['currentSlideIndex'] as int? ?? 0,
      // If it comes from backend (has _id), it is synced. 
      // If loaded from local storage, use the stored value.
      isSynced: json.containsKey('_id') ? true : (json['isSynced'] ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'creationDate': creationDate,
      'slides': slides.map((s) => s.toJson()).toList(),
      'currentSlideIndex': currentSlideIndex,
      'isSynced': isSynced,
    };
  }

  WhiteBoard copyWith({
    String? id,
    String? title,
    String? creationDate,
    List<Slide>? slides,
    int? currentSlideIndex,
    bool? isSynced,
  }) {
    return WhiteBoard(
      id: id ?? this.id,
      title: title ?? this.title,
      creationDate: creationDate ?? this.creationDate,
      slides: slides ?? List<Slide>.from(this.slides),
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}