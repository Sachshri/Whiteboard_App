import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';
import 'package:white_boarding_app/widgets/dialog_boxes.dart';
import 'package:white_boarding_app/widgets/slide_thumbnail_canvas.dart';
import '../models/white_board.dart';
import '../models/white_board_history.dart';
import '../models/ui_state.dart';
import '../viewmodels/tool_viewmodel.dart';
import '../viewmodels/active_board_viewmodel.dart';
import '../widgets/canvas_widget.dart';

final slideManagerVisibleProvider = StateProvider<bool>((ref) => true);

class WhiteBoardScreen extends ConsumerWidget {
final WhiteBoard whiteBoard;
const WhiteBoardScreen({super.key, required this.whiteBoard});

@override
Widget build(BuildContext context, WidgetRef ref) {
 return ProviderScope(
 overrides: [
  // FIX 1: Correct Riverpod syntax for overriding a family provider
  activeBoardHistoryProvider(whiteBoard).overrideWith(
  (ref) => ActiveBoardNotifier(whiteBoard, ref),
  ),
 ],
 // FIX 2: Pass the required argument to the child widget
 child: _WhiteBoardScreenContent(whiteBoard: whiteBoard),
 );
}
}

class _WhiteBoardScreenContent extends ConsumerWidget {
// FIX 3: Accept the required board instance as a parameter
final WhiteBoard whiteBoard;
const _WhiteBoardScreenContent({required this.whiteBoard});

@override
Widget build(BuildContext context, WidgetRef ref) {
 // FIX 4: Watch the family provider using the board argument
 final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
 final activeBoard = history.currentBoard;
 final size = MediaQuery.of(context).size;
 final isMobile = size.width < 600;
 final isTablet = size.width >= 600 && size.width < 910;
 final isDesktop = size.width >= 910;
 final activeTool = ref.watch(toolStateProvider);

 final currentSlideIndex = activeBoard.currentSlideIndex;
 final isSlideManagerVisible = ref.watch(slideManagerVisibleProvider);

 Widget toolbox = _buildToolbox(ref, activeTool, isDesktop);

 return Scaffold(
 appBar: AppBar(
  backgroundColor: Colors.transparent,
  elevation: 0,
  leading: IconButton(
  icon: const Icon(Icons.arrow_back, color: Colors.black54),
  onPressed: () => Navigator.pop(context),
  ),
  title: GestureDetector(
  onDoubleTap: () => DialogBoxes.showTitleEditDialog(
   context,
   ref,
   activeBoard,
   true,
   // FIX 5: Read the notifier using the family argument
   localNotifier: ref.read(activeBoardHistoryProvider(whiteBoard).notifier),
  ),
  child: Text(
   activeBoard.title,
   style: const TextStyle(
   color: Colors.black87,
   fontWeight: FontWeight.bold,
   fontSize: 16,
   ),
  ),
  ),
  actions: _buildAppBarActions(ref, history, isDesktop, isTablet),
 ),
 body: Container(
  decoration: const BoxDecoration(
  image: DecorationImage(
   image: AssetImage('assets/background.png'),
   fit: BoxFit.cover,
   opacity: 1.0,
  ),
  ),
  child: isMobile
   ? _buildMobileLayout(context, ref, toolbox, activeTool)
   : _buildDesktopTabletLayout(
    ref,
    toolbox,
    activeTool,
    currentSlideIndex,
    isSlideManagerVisible,
   ),
 ),
 );
}

List<Widget> _buildAppBarActions(
 WidgetRef ref,
 WhiteBoardHistory history,
 bool isDesktop,
 bool isTablet,
) {
 // FIX 6: Read the notifier using the family argument
 final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);

 return [
 IconButton(
  icon: Icon(
  Icons.undo,
  color: history.canUndo ? Colors.black54 : Colors.grey,
  ),
  onPressed: history.canUndo ? notifier.undo : null,
 ),
 IconButton(
  icon: Icon(
  Icons.redo,
  color: history.canRedo ? Colors.black54 : Colors.grey,
  ),
  onPressed: history.canRedo ? notifier.redo : null,
 ),

 if (isDesktop || isTablet)
  IconButton(
  icon: Icon(
   Icons.layers_outlined,
   color: ref.watch(slideManagerVisibleProvider)
    ? const Color(0xFF55B8B9)
    : Colors.black54,
  ),
  onPressed: () {
   ref.read(slideManagerVisibleProvider.notifier).state = !ref.read(
   slideManagerVisibleProvider,
   );
  },
  ),
 // IconButton(
 // icon: const Icon(Icons.more_vert, color: Colors.black54),
 // onPressed: () => debugPrint('Settings Menu'),
 // ),
 const SizedBox(width: 8),
 ];
}

Widget _buildDesktopTabletLayout(
 WidgetRef ref,
 Widget toolbox,
 ToolType activeTool,
 int currentSlideIndex,
 bool isSlideManagerVisible,
) {
 // FIX 7: Watch the history using the family argument
 final activeBoard = ref.watch(activeBoardHistoryProvider(whiteBoard)).currentBoard;

 return Column(
 children: [
  Expanded(
  child: Row(
   children: [
   Padding(
    padding: const EdgeInsets.only(left: 20, top: 20),
    child: SingleChildScrollView(child: toolbox),
   ),

   Expanded(
    child: CanvasWidget(
    whiteBoard: activeBoard,
    ),
   ),

   if (isSlideManagerVisible)
    Padding(
    padding: const EdgeInsets.only(right: 20, top: 20),
    child: _buildSlideManager(ref, currentSlideIndex),
    ),
   ],
  ),
  ),

  _buildDesktopBottomBar(ref, activeTool),
 ],
 );
}

Widget _buildMobileLayout(
 BuildContext context,
 WidgetRef ref,
 Widget toolbox,
 ToolType activeTool,
) {
 // FIX 8: Watch the history using the family argument
 final activeBoard = ref.watch(activeBoardHistoryProvider(whiteBoard)).currentBoard;

 return Stack(
 children: [
  CanvasWidget(
  whiteBoard: activeBoard,
  ),

  Align(
  alignment: Alignment.topLeft,
  child: Padding(
   padding: const EdgeInsets.only(left: 8, top: 8),
   child: toolbox,
  ),
  ),

  Align(
  alignment: Alignment.bottomCenter,
  child: _buildMobileBottomBar(context, ref, activeTool),
  ),
 ],
 );
}

Widget _buildDesktopBottomBar(WidgetRef ref, ToolType activeTool) {
 // FIX 9: Watch the history using the family argument
 final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
 final activeBoard = history.currentBoard;
 // FIX 9 (cont): Read the notifier using the family argument
 final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);
 final currentSlideIndex = activeBoard.currentSlideIndex;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
 decoration: BoxDecoration(
  color: Colors.white38,
  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
 ),
 child: Row(
  children: [
  IconButton(
   icon: const Icon(Icons.chevron_left, color: Colors.black54),
   onPressed: currentSlideIndex > 0
    ? () => notifier.changeSlide(currentSlideIndex - 1)
    : null,
  ),
  Container(
   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
   decoration: BoxDecoration(
   color: const Color(0xFF55B8B9).withAlpha(160),
   borderRadius: BorderRadius.circular(6),
   ),
   child: Text(
   '${currentSlideIndex + 1} / ${activeBoard.slides.length}',
   style: const TextStyle(
    fontWeight: FontWeight.bold,
    color: Color.fromARGB(255, 237, 241, 241),
   ),
   ),
  ),
  IconButton(
   icon: const Icon(Icons.chevron_right, color: Colors.black54),
   onPressed: currentSlideIndex < activeBoard.slides.length - 1
    ? () => notifier.changeSlide(currentSlideIndex + 1)
    : null,
  ),
  IconButton(
   icon: const Icon(Icons.add, color: Colors.black54),
   onPressed: () => notifier.addSlide(),
  ),
 
  const Padding(
   padding: EdgeInsets.symmetric(horizontal: 10),
   child: SizedBox(
   height: 24,
   child: VerticalDivider(color: Colors.black26),
   ),
  ),
 
  Expanded(
   child: Padding(
   padding: const EdgeInsets.only(left: 10),
   child: SingleChildScrollView(scrollDirection: Axis.horizontal,child: _buildToolPropertiesPanel(ref, activeTool, true)),
   ),
  ),
  ],
 ),
 );
}

void _showStrokeWidthSelector(BuildContext context, WidgetRef ref) {
 final provider = ref.read(toolOptionsProvider.notifier);
 final options = provider.state;

 // Define available stroke widths
 const List<double> widths = [2.0, 4.0, 6.0, 8.0, 12.0, 16.0];

 showModalBottomSheet(
 context: context,
 backgroundColor: Colors.transparent,
 builder: (BuildContext bc) {
  return Container(
  padding: const EdgeInsets.all(16.0),
  decoration: const BoxDecoration(
   color: Colors.white,
   borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  child: Column(
   mainAxisSize: MainAxisSize.min,
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
   const Text(
    'Select Stroke Width',
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
   ),
   const Divider(),
   SizedBox(
    height: 50,
    child: ListView(
    scrollDirection: Axis.horizontal,
    children: widths.map((width) {
     final isSelected = options.strokeWidth == width;
     return Padding(
     padding: const EdgeInsets.symmetric(horizontal: 8.0),
     child: InkWell(
      onTap: () {
      provider.state = options.copyWith(strokeWidth: width);
      Navigator.pop(bc); // Close the modal
      },
      child: Center(
      child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
       Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
        color: isSelected
         ? const Color(0xFF55B8B9).withAlpha(54)
         : Colors.transparent,
        shape: BoxShape.circle,
        border: isSelected
         ? Border.all(
          color: const Color(0xFF55B8B9),
          width: 2,
          )
         : null,
        ),
        child: Center(
        child: Container(
         width: width,
         height: width,
         decoration: const BoxDecoration(
         color: Colors
          .black, // Use stroke color from options in production
         shape: BoxShape.circle,
         ),
        ),
        ),
       ),
       if (isSelected)
        const Text(
        'Current',
        style: TextStyle(
         fontSize: 10,
         color: Color(0xFF55B8B9),
        ),
        ),
       ],
      ),
      ),
     ));
    }).toList(),
    ),
   ),
   ],
  ),
  );
 },
 );
}

// --- Corrected _buildMobileBottomBar Widget ---
Widget _buildMobileBottomBar(
 BuildContext context,
 WidgetRef ref,
 ToolType activeTool,
) {
 // FIX 9 (part 1): Watch the history using the family argument
 final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
 final activeBoard = history.currentBoard;
 // FIX 9 (part 2): Read the notifier using the family argument
   final selectedIds = ref.watch(selectedObjectIdsProvider(whiteBoard));
  final isObjectSelected = selectedIds.isNotEmpty;
 final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);
 final currentSlideIndex = activeBoard.currentSlideIndex;
 final options = ref.watch(toolOptionsProvider);

 return SingleChildScrollView(
  scrollDirection: Axis.horizontal,
   child: Container(
   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
   
   decoration: BoxDecoration(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
    // Corrected Color to use the translucent alpha previously defined
    color: Colors.white.withAlpha(217), // Alpha 217 (~85% opacity)
   ),
   child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
    // Slide Navigation: Previous Slide (Down Arrow)
    IconButton(
     // Corrected functionality to move to PREVIOUS slide (index - 1)
     icon: const Icon(
     Icons.arrow_upward_outlined,
     color: Colors.black54,
     ),
     onPressed: currentSlideIndex > 0
      ? () => notifier.changeSlide(currentSlideIndex - 1)
      : null,
    ),
   
    // Slide Counter
    Container(
     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
     decoration: BoxDecoration(
     // Using a lighter opacity background for the number box
     color: const Color(0xFF55B8B9).withAlpha(27),
     borderRadius: BorderRadius.circular(6),
     ),
     child: Text(
     '${currentSlideIndex + 1} / ${activeBoard.slides.length}',
     style: const TextStyle(
      fontWeight: FontWeight.bold,
      color: Color(0xFF55B8B9),
      fontSize: 14,
     ),
     ),
    ),
   
    // Slide Navigation: Next Slide (Up Arrow)
    IconButton(
     // Corrected functionality to move to NEXT slide (index + 1)
     icon: const Icon(
     Icons.arrow_downward_outlined,
     color: Colors.black54,
     ),
     onPressed: currentSlideIndex < activeBoard.slides.length - 1
      ? () => notifier.changeSlide(currentSlideIndex + 1)
      : null,
    ),
   
    IconButton(
     // Corrected functionality to move to NEXT slide (index + 1)
     icon: const Icon(Icons.add, color: Colors.black54),
     onPressed: () => notifier.addSlide(),
    ),
   
    const SizedBox(width: 10),
   
    // Tool Properties
     if (activeTool == ToolType.selection && isObjectSelected) 
     // SELECTION TOOL PROPERTIES (Delete/Duplicate/Modify)
    Row(
       children: [
         const Text(
           "Selection:",
           style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
         ),
         const SizedBox(width: 10),
         
         // Delete Button
         IconButton(
           icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
           tooltip: 'Delete Selected Object(s) (Delete/Backspace)',
           onPressed: () => notifier.deleteSelectedObjects(whiteBoard),
         ),
         
         // Duplicate Button (Ctrl+V)
         IconButton(
           icon: const Icon(Icons.copy_all_outlined, color: Colors.black54),
           tooltip: 'Duplicate Selected Object(s) (Ctrl+V)',
           onPressed: () => notifier.duplicateSelectedObjects(whiteBoard), // Call new method
         ),
         const SizedBox(width: 10),
         // TODO: Add controls for changing attributes (color, thickness) of selected object here
         
       ],
     ),
    if ([
     ToolType.pencil,
     ToolType.text,
     ToolType.circle,
     ToolType.rectangle,
     ToolType.line,
     ToolType.arrow,
    ].contains(activeTool)) ...[
     // Stroke Color Display/Picker
     Container(
     width: 24,
     height: 24,
     decoration: BoxDecoration(
      color: Color(int.parse(options.color.replaceAll('#', '0xFF'))),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black26),
     ),
     ),
   
     // Stroke Width Selector (Interactive)
     GestureDetector(
     onTap: () => _showStrokeWidthSelector(
      context,
      ref,
     ), // Show the modal on tap
     child: Container(
      width: 32, // Slightly larger tap area
      height: 32,
      decoration: BoxDecoration(
      border: Border.all(color: Colors.black, width: 1.0),
      borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
      child: Text(
       options.strokeWidth.round().toString(),
       style: const TextStyle(fontSize: 12),
      ),
      ),
     ),
     ),
    ],
   
    // Current Active Tool Icon
    Container(
     padding: const EdgeInsets.all(8),
     decoration: BoxDecoration(
     color: const Color(0xFF86DAB9),
     borderRadius: BorderRadius.circular(8),
     ),
     child: _getToolIcon(
     activeTool,
     ), // Assuming _getToolIcon is available
    ),
    ],
   ),
   ),
 );
}

Widget _buildToolPropertiesPanel(
 WidgetRef ref,
 ToolType activeTool,
 bool isDesktop,
) {
 final options = ref.watch(toolOptionsProvider);
 final optionsNotifier = ref.read(toolOptionsProvider.notifier);
  // NEW: Check if an object is selected
  final selectedIds = ref.watch(selectedObjectIdsProvider(whiteBoard));
  final isObjectSelected = selectedIds.isNotEmpty;
  final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);
  
  // Logic: Show creation tool properties OR selection tool properties
  
  if (activeTool == ToolType.selection && isObjectSelected) {
     // SELECTION TOOL PROPERTIES (Delete/Duplicate/Modify)
     return Row(
       children: [
         const Text(
           "Selection:",
           style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
         ),
         const SizedBox(width: 10),
         
         // Delete Button
         IconButton(
           icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
           tooltip: 'Delete Selected Object(s) (Delete/Backspace)',
           onPressed: () => notifier.deleteSelectedObjects(whiteBoard),
         ),
         
         // Duplicate Button (Ctrl+V)
         IconButton(
           icon: const Icon(Icons.copy_all_outlined, color: Colors.black54),
           tooltip: 'Duplicate Selected Object(s) (Ctrl+V)',
           onPressed: () => notifier.duplicateSelectedObjects(whiteBoard), // Call new method
         ),
         const SizedBox(width: 10),
         // TODO: Add controls for changing attributes (color, thickness) of selected object here
         
       ],
     );
   }

 if (![
 ToolType.pencil,
 ToolType.rectangle,
 ToolType.circle,
 ToolType.line,
 ToolType.arrow,
 ToolType.text,
 ToolType.eraser,
 ].contains(activeTool)) {
 return const SizedBox.shrink();
 }

 if (isDesktop) {
 return Row(
  mainAxisAlignment: MainAxisAlignment.start,
  children: [
  const Padding(
   padding: EdgeInsets.only(right: 10),
   child: Text(
   "Properties:",
   style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
   ),
  ),

  SizedBox(
   width: 150, // Added width for better control on desktop
   child: Slider(
   value: options.strokeWidth,
   activeColor: Colors.blue,
   min: 1,
   max: 16,
   divisions: 15,
   onChanged: (v) =>
    optionsNotifier.state = options.copyWith(strokeWidth: v),
   ),
  ),
  const SizedBox(width: 10),

  // Display the current width value
  SizedBox(
   width: 30,
   child: Text(
   options.strokeWidth.toStringAsFixed(0),
   style: TextStyle(fontWeight: FontWeight.bold),
   textAlign: TextAlign.center,
   ),
  ),
  const SizedBox(width: 20),

  if (![ToolType.eraser].contains(activeTool)) ...[
   const Text("Color: "),
   InkWell(
   // onTap: () => _showColorPicker(context, ref, 'color'), // TODO: Implement color picker modal
   child: Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
    color: Color(
     int.parse(options.color.replaceAll('#', '0xFF')),
    ),
    shape: BoxShape.circle,
    border: Border.all(color: Colors.black26),
    ),
   ),
   ),
  ],

  const SizedBox(width: 20),

  if ([ToolType.rectangle, ToolType.circle].contains(activeTool)) ...[
   const Text("Fill: "),
   InkWell(
   // onTap: () => _showColorPicker(context, ref, 'fillColor'), // TODO: Implement color picker modal
   child: Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
    color: Color(
     int.parse(options.fillColor.replaceAll('#', '0xFF')),
    ),
    shape: BoxShape.circle,
    border: Border.all(color: Colors.black26),
    ),
   ),
   ),
  ],
  ],
 );
 }

 return const SizedBox.shrink();
}

Widget _buildSlideManager(WidgetRef ref, int currentSlideIndex) {
 // FIX 9 (part 3): Watch the history using the family argument
 final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
 final activeBoard = history.currentBoard;
 // FIX 9 (part 4): Read the notifier using the family argument
 final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);

 return Container(
 width: 200,
 margin: EdgeInsets.only(bottom: 15),
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
  color: Colors.white70,
  borderRadius: BorderRadius.circular(16),
  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
 ),
 child: Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
  const Text(
   'SLIDES',
   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
  ),
  const Divider(height: 10),

  Expanded(
   child: ReorderableListView.builder(
   shrinkWrap: true,
   itemCount: activeBoard.slides.length,
   onReorder: (oldIndex, newIndex) {
    if (oldIndex < newIndex) {
    newIndex -= 1;
    }
    notifier.moveSlide(oldIndex, newIndex);
   },
   itemBuilder: (context, index) {
    final isSelected = index == currentSlideIndex;
    final slide = activeBoard.slides[index];
    return Card(
    key: ValueKey(activeBoard.slides[index].id),
    margin: const EdgeInsets.symmetric(
     vertical: 4,
     horizontal: 2,
    ),
    color: isSelected ? const Color(0xFF55B8B9) : Colors.white,
    child: Padding(
     padding: const EdgeInsets.only(right: 8.0),

     child: GestureDetector(
     onTap: () => notifier.changeSlide(index),
     child: Stack(
      children: [
      Container(
       padding: EdgeInsets.all(8),
       child: SlideThumbnailCanvas(
       slide: slide,
       width: 130, // Small width for sidebar
       height: 78, // Small height for sidebar
       ),
      ),

      Align(
       alignment: AlignmentGeometry.bottomRight,
       child: IconButton(
       icon: Icon(
        Icons.delete_outline,
        size: 20,
        color: Colors.redAccent,
       ),
       onPressed: () {
        if (activeBoard.slides.length > 1) {
        notifier.deleteSlide(index);
        } else {
        DialogBoxes.showWarningDialog(
         context,
         message:
          "Atleast one slide needed Or WhiteBoard will be deleted on 'OK'",
         onConfirm: () {
         ref
          .read(whiteBoardListProvider.notifier)
          .deleteBoard(activeBoard.id);
         Navigator.of(context).pop();
         },
        );
        }
       },
       ),
      ),
      ],
     ),
     ),
    ));
   },
   ),
  ),

  _buildGradientButton(
   onPressed: notifier.addSlide,
   label: 'Add Slide',
   icon: Icons.add,
   gradient: const LinearGradient(
   colors: [Color(0xFFD48FFC), Color(0xFFA671FF)],
   ),
  ),
  ],
 ),
 );
}

Widget _buildToolbox(WidgetRef ref, ToolType activeTool, bool isDesktop) {
 final notifier = ref.read(toolStateProvider.notifier);
 const List<(ToolType, IconData)> tools = [
 (ToolType.selection, Icons.touch_app_outlined),
 (ToolType.pan, Icons.pan_tool_outlined),
 (ToolType.pencil, Icons.brush_outlined),
 (ToolType.eraser, Icons.cleaning_services_outlined),
 (ToolType.line, Icons.horizontal_rule_rounded),
 (ToolType.rectangle, Icons.crop_square),
 (ToolType.circle, Icons.circle_outlined),
 (ToolType.arrow, Icons.arrow_forward_rounded),
 (ToolType.text, Icons.text_fields_outlined),
 (ToolType.image, Icons.image_outlined),
 ];

 return SingleChildScrollView(
  scrollDirection: Axis.vertical,
   child: Container(
   padding: const EdgeInsets.all(8),
   decoration: BoxDecoration(
    color: Colors.white70,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
   ),
   child: Column(
    mainAxisSize: MainAxisSize.min,
    children: tools.map((tool) {
    final isSelected = activeTool == tool.$1;
    return Padding(
     padding: const EdgeInsets.symmetric(vertical: 4.0),
     child: Tooltip(
     message: tool.$1.toString().split('.').last.toUpperCase(),
     child: InkWell(
      onTap: () => notifier.selectTool(tool.$1),
      child: Container(
      width: isDesktop ? 40 : 36,
      height: isDesktop ? 40 : 36,
      decoration: BoxDecoration(
       color: isSelected
        ? const Color(0xFF55B8B9)
        : Colors.transparent,
       borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
       tool.$2,
       color: isSelected ? Colors.white : Colors.black54,
       size: isDesktop ? 22 : 18,
      ),
      ),
     ),
     ),
    );
    }).toList(),
   ),
   ),
 );
}

Widget _getToolIcon(ToolType type) {
 return switch (type) {
 ToolType.selection => const Icon(
  Icons.touch_app_outlined,
  color: Colors.white,
 ),
 ToolType.pan => const Icon(Icons.pan_tool_outlined, color: Colors.white),
 ToolType.pencil => const Icon(Icons.brush_outlined, color: Colors.white),
 ToolType.eraser => const Icon(
  Icons.cleaning_services_outlined,
  color: Colors.white,
 ),
 ToolType.rectangle => const Icon(Icons.crop_square, color: Colors.white),
 ToolType.circle => const Icon(Icons.circle_outlined, color: Colors.white),
 ToolType.arrow => const Icon(
  Icons.arrow_forward_rounded,
  color: Colors.white,
 ),
 ToolType.line => const Icon(
  Icons.horizontal_rule_rounded,
  color: Colors.white,
 ),
 ToolType.text => const Icon(
  Icons.text_fields_outlined,
  color: Colors.white,
 ),
 ToolType.image => const Icon(Icons.image_outlined, color: Colors.white),
 };
}

Widget _buildGradientButton({
 required VoidCallback onPressed,
 required String label,
 required IconData icon,
 required Gradient gradient,
}) {
 return Container(
 decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(10),
  gradient: gradient,
  boxShadow: [
  BoxShadow(
   color: Colors.black.withAlpha(26),
   blurRadius: 4,
   offset: const Offset(0, 2),
  ),
  ],
 ),
 child: Material(
  color: Colors.transparent,
  child: InkWell(
  onTap: onPressed,
  borderRadius: BorderRadius.circular(10),
  child: Padding(
   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
   child: Row(
   mainAxisAlignment: MainAxisAlignment.center,
   children: [
    Icon(icon, size: 16, color: Colors.white),
    const SizedBox(width: 6),
    Text(
    label,
    style: const TextStyle(
     color: Colors.white,
     fontWeight: FontWeight.bold,
     fontSize: 14,
    ),
    ),
   ],
   ),
  ),
  ),
 ));
 }
}

