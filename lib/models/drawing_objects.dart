class Attributes {
  double x;
  double y;
  double width;
  double height;
  double strokeWidth;
  String strokeColor;
  String fillColor;
  double opacity;

  Attributes({
    required this.x,
    required this.y,
    this.width = 0.0,
    this.height = 0.0,
    this.strokeWidth = 1.0,
    this.strokeColor = '#000000',
    this.fillColor = '#FFFFFF',
    this.opacity = 1.0,
  });

  factory Attributes.fromJson(Map<String, dynamic> json) {
    return Attributes(
      x: json['x'] as double,
      y: json['y'] as double,
      width: json['width'] as double? ?? 0.0,
      height: json['height'] as double? ?? 0.0,
      strokeWidth: json['strokeWidth'] as double? ?? 1.0,
      strokeColor: json['strokeColor'] as String? ?? '#000000',
      fillColor: json['fillColor'] as String? ?? '#FFFFFF',
      opacity: json['opacity'] as double? ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'strokeWidth': strokeWidth,
      'strokeColor': strokeColor,
      'fillColor': fillColor,
      'opacity': opacity,
    };
  }
  Attributes copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? strokeWidth,
    String? strokeColor,
    String? fillColor,
    double? opacity,
  }) {
    return Attributes(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: fillColor ?? this.fillColor,
      opacity: opacity ?? this.opacity,
    );
  }
}

// --- Pen/Pencil Point Data ---
class PointData {
  double x;
  double y;

  PointData({required this.x, required this.y});

  factory PointData.fromJson(Map<String, dynamic> json) {
    return PointData(
      x: json['x'] as double,
      y: json['y'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}
// -- Eraser Object ---
class EraserObject {
  String id;
  String type = 'eraser'; // IMPORTANT: New type
  List<PointData> points;
  double strokeWidth;

  EraserObject({
    required this.id,
    required this.points,
    required this.strokeWidth,
  });

  factory EraserObject.fromJson(Map<String, dynamic> json) {
    return EraserObject(
      id: json['id'] as String,
      points: (json['points'] as List<dynamic>)
          .map((p) => PointData.fromJson(p as Map<String, dynamic>))
          .toList(),
      strokeWidth: json['strokeWidth'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'points': points.map((p) => p.toJson()).toList(),
      'strokeWidth': strokeWidth,
    };
  }
  
  // copyWith is useful for the updateDrawing logic
  EraserObject copyWith({
    String? id,
    List<PointData>? points,
    double? strokeWidth,
  }) {
    return EraserObject(
      id: id ?? this.id,
      points: points ?? this.points,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}
// --- Pen Object ---
class PenObject {
  String id;
  String type = 'pen';
  List<PointData> points;
  double strokeWidth;
  String color;
  double opacity;

  PenObject({
    required this.id,
    required this.points,
    required this.strokeWidth,
    required this.color,
    required this.opacity,
  });

  factory PenObject.fromJson(Map<String, dynamic> json) {
    return PenObject(
      id: json['id'] as String,
      points: (json['points'] as List<dynamic>)
          .map((p) => PointData.fromJson(p as Map<String, dynamic>))
          .toList(),
      strokeWidth: json['strokeWidth'] as double,
      color: json['color'] as String,
      opacity: json['opacity'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'points': points.map((p) => p.toJson()).toList(),
      'strokeWidth': strokeWidth,
      'color': color,
      'opacity': opacity,
    };
  }
  PenObject copyWith({
    String? id,
    List<PointData>? points,
    double? strokeWidth,
    String? color,
    double? opacity,
  }) {
    return PenObject(
      id: id ?? this.id,
      points: points ?? List<PointData>.from(this.points),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
    );
  }
}

// --- Generic Drawing Object (for all other shapes) ---
class DrawingObject {
  String id;
  String type; 
  Attributes attributes;

  DrawingObject({
    required this.id,
    required this.type,
    required this.attributes,
  });

  factory DrawingObject.fromJson(Map<String, dynamic> json) {
    return DrawingObject(
      id: json['id'] as String,
      type: json['type'] as String,
      attributes: Attributes.fromJson(json['attributes'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'attributes': attributes.toJson(),
    };
  }
}

extension DrawingObjectCopy on DrawingObject {
  DrawingObject copyWith({
    String? id,
    String? type,
    Attributes? attributes,
  }) {
    return DrawingObject(
      id: id ?? this.id,
      type: type ?? this.type,
      attributes: attributes ?? this.attributes,
    );
  }
}