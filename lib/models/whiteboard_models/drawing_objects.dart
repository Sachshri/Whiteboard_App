// lib/models/whiteboard_models/drawing_objects.dart

class Attributes {
  double x;
  double y;
  double width;
  double height;
  double strokeWidth;
  String strokeColor;
  String fillColor;
  double opacity;
  
  String? text; 
  double fontSize; 

  Attributes({
    required this.x,
    required this.y,
    this.width = 0.0,
    this.height = 0.0,
    this.strokeWidth = 1.0,
    this.strokeColor = '#000000',
    this.fillColor = '#FFFFFF',
    this.opacity = 1.0,
    this.text, 
    this.fontSize = 20.0, 
  });

  factory Attributes.fromJson(Map<String, dynamic> json) {
    return Attributes(
      // FIX: Use 'as num?' to allow nulls, then '?.' to call toDouble, then '??' for default
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.0,
      strokeColor: json['strokeColor'] as String? ?? '#000000',
      fillColor: json['fillColor'] as String? ?? '#FFFFFF',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      text: json['text'] as String? ?? json['value'] as String?, // Handle 'value' key from backend text objects
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 
                (json['fontWidth'] as num?)?.toDouble() ?? 20.0, // Handle 'fontWidth' from backend
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
      'text': text, 
      'fontSize': fontSize, 
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
    String? text, 
    double? fontSize, 
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
      text: text ?? this.text, 
      fontSize: fontSize ?? this.fontSize,
    );
  }
}


class PointData {
  double x;
  double y;

  PointData({required this.x, required this.y});

  factory PointData.fromJson(Map<String, dynamic> json) {
    return PointData(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}


class PenObject {
  String id;
  String type = 'pen';
  List<PointData> points;
  double strokeWidth;
  String color;
  double opacity;
  bool isEraser; 

  PenObject({
    required this.id,
    required this.points,
    required this.strokeWidth,
    required this.color,
    required this.opacity,
    this.isEraser = false, 
  });

  factory PenObject.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'] as Map<String, dynamic>? ?? {};

    // 2. Helper to get value from Root OR Attributes (Prioritize Attributes for DB data)
    dynamic getValue(String key) {
      return attributes[key] ?? json[key];
    }

    return PenObject(
      id: json['id'] as String? ?? '', 
      
      // 3. Retrieve points correctly
      points: ((getValue('points') ?? []) as List<dynamic>)
          .map((p) => PointData.fromJson(p as Map<String, dynamic>))
          .toList(),
      
      // 4. Retrieve style properties correctly
      strokeWidth: (getValue('strokeWidth') as num?)?.toDouble() ?? 3.0,
      
      // Handle color key variations (backend might save as 'color' or 'strokeColor')
      color: getValue('color') ?? getValue('strokeColor') ?? '#000000',
      
      opacity: (getValue('opacity') as num?)?.toDouble() ?? 1.0,
      isEraser: getValue('isEraser') as bool? ?? false,
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
      'isEraser': isEraser, 
    };
  }

  PenObject copyWith({
    String? id,
    List<PointData>? points,
    double? strokeWidth,
    String? color,
    double? opacity,
    bool? isEraser, 
  }) {
    return PenObject(
      id: id ?? this.id,
      points: points ?? List<PointData>.from(this.points),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      isEraser: isEraser ?? this.isEraser,
    );
  }
}

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
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'rectangle',
      attributes: Attributes.fromJson(json['attributes'] as Map<String, dynamic>? ?? {}),
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