import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/whiteboard_models/ui_state.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/utils/helpers/helpers.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';
import 'package:white_boarding_app/utils/helpers/dialog_boxes.dart';
import 'package:white_boarding_app/view/whiteboard/widgets/slide_thumbnail_canvas.dart';
import '../../viewmodels/tool_viewmodel.dart';
import '../../viewmodels/active_board_viewmodel.dart';
import 'widgets/canvas_widget.dart';

final slideManagerVisibleProvider = StateProvider<bool>((ref) => true);

class WhiteBoardScreen extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  const WhiteBoardScreen({super.key, required this.whiteBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        activeBoardHistoryProvider(whiteBoard).overrideWith((ref) => ActiveBoardNotifier(whiteBoard, ref)),
      ],
      child: _WhiteBoardScreenContent(whiteBoard: whiteBoard),
    );
  }
}

class _WhiteBoardScreenContent extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  const _WhiteBoardScreenContent({required this.whiteBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
    final activeBoard = history.currentBoard;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 910;
    final isDesktop = size.width >= 910;

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
            localNotifier: ref.read(activeBoardHistoryProvider(whiteBoard).notifier),
          ),
          child: Text(
            activeBoard.title,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        actions: [
          _AppBarActions(whiteBoard: whiteBoard, isDesktopOrTablet: isDesktop || isTablet)
        ],
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
            ? MobileLayout(whiteBoard: whiteBoard)
            : DesktopTabletLayout(whiteBoard: whiteBoard, isSlideManagerVisible: ref.watch(slideManagerVisibleProvider)),
      ),
    );
  }
}

// --- Layout Widgets ---

class DesktopTabletLayout extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  final bool isSlideManagerVisible;

  const DesktopTabletLayout({
    super.key,
    required this.whiteBoard,
    required this.isSlideManagerVisible,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBoard = ref.watch(activeBoardHistoryProvider(whiteBoard)).currentBoard;
    final activeTool = ref.watch(toolStateProvider);

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 20),
                child: SingleChildScrollView(
                  child: WhiteBoardToolbox(isDesktop: true),
                ),
              ),
              Expanded(child: CanvasWidget(whiteBoard: activeBoard)),
              if (isSlideManagerVisible)
                Padding(
                  padding: const EdgeInsets.only(right: 20, top: 20),
                  child: SlideManagerWidget(whiteBoard: whiteBoard),
                ),
            ],
          ),
        ),
        DesktopBottomBar(whiteBoard: whiteBoard, activeTool: activeTool),
      ],
    );
  }
}

class MobileLayout extends ConsumerWidget {
  final WhiteBoard whiteBoard;

  const MobileLayout({super.key, required this.whiteBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBoard = ref.watch(activeBoardHistoryProvider(whiteBoard)).currentBoard;
    final activeTool = ref.watch(toolStateProvider);

    return Stack(
      children: [
        CanvasWidget(whiteBoard: activeBoard),
        const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 8, top: 8),
            child: WhiteBoardToolbox(isDesktop: false),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: MobileBottomBar(whiteBoard: whiteBoard, activeTool: activeTool),
        ),
      ],
    );
  }
}

// --- Functional Components converted to Widgets ---

class _AppBarActions extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  final bool isDesktopOrTablet;

  const _AppBarActions({required this.whiteBoard, required this.isDesktopOrTablet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
    final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.undo, color: history.canUndo ? Colors.black54 : Colors.grey),
          onPressed: history.canUndo ? notifier.undo : null,
        ),
        IconButton(
          icon: Icon(Icons.redo, color: history.canRedo ? Colors.black54 : Colors.grey),
          onPressed: history.canRedo ? notifier.redo : null,
        ),
        if (isDesktopOrTablet)
          IconButton(
            icon: Icon(
              Icons.layers_outlined,
              color: ref.watch(slideManagerVisibleProvider) ? const Color(0xFF55B8B9) : Colors.black54,
            ),
            onPressed: () {
              ref.read(slideManagerVisibleProvider.notifier).state = !ref.read(slideManagerVisibleProvider);
            },
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class WhiteBoardToolbox extends ConsumerWidget {
  final bool isDesktop;

  const WhiteBoardToolbox({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(toolStateProvider);
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

    return Container(
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
                    color: isSelected ? const Color(0xFF55B8B9) : Colors.transparent,
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
    );
  }
}

class DesktopBottomBar extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  final ToolType activeTool;

  const DesktopBottomBar({super.key, required this.whiteBoard, required this.activeTool});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
    final activeBoard = history.currentBoard;
    final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);
    final currentSlideIndex = activeBoard.currentSlideIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white38,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black54),
            onPressed: currentSlideIndex > 0 ? () => notifier.changeSlide(currentSlideIndex - 1) : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF55B8B9).withAlpha(160),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${currentSlideIndex + 1} / ${activeBoard.slides.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 237, 241, 241)),
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
            child: SizedBox(height: 24, child: VerticalDivider(color: Colors.black26)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ToolPropertiesPanel(whiteBoard: whiteBoard, activeTool: activeTool, isDesktop: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileBottomBar extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  final ToolType activeTool;

  const MobileBottomBar({super.key, required this.whiteBoard, required this.activeTool});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
    final activeBoard = history.currentBoard;
    final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);
    final currentSlideIndex = activeBoard.currentSlideIndex;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          color: Colors.white.withAlpha(217),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward_outlined, color: Colors.black54),
              onPressed: currentSlideIndex > 0 ? () => notifier.changeSlide(currentSlideIndex - 1) : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF55B8B9).withAlpha(27),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${currentSlideIndex + 1} / ${activeBoard.slides.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF55B8B9), fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward_outlined, color: Colors.black54),
              onPressed: currentSlideIndex < activeBoard.slides.length - 1
                  ? () => notifier.changeSlide(currentSlideIndex + 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black54),
              onPressed: () => notifier.addSlide(),
            ),
            const SizedBox(width: 10),
            
            // Reusing the Logic from ToolPropertiesPanel but adapted for Mobile Row
            // In Mobile, we just show properties directly in this row
            ToolPropertiesPanel(whiteBoard: whiteBoard, activeTool: activeTool, isDesktop: false),
            
             const SizedBox(width: 10),
             
             // Current Active Tool Icon Indication
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: const Color(0xFF86DAB9),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: ToolIconWidget(type: activeTool),
             ),
          ],
        ),
      ),
    );
  }
}

class ToolPropertiesPanel extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  final ToolType activeTool;
  final bool isDesktop;

  const ToolPropertiesPanel({
    super.key,
    required this.whiteBoard,
    required this.activeTool,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(toolOptionsProvider);
    final optionsNotifier = ref.read(toolOptionsProvider.notifier);
    final selectedIds = ref.watch(selectedObjectIdsProvider(whiteBoard));
    final isObjectSelected = selectedIds.isNotEmpty;
    final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);

    // --- SELECTION Properties ---
    if (activeTool == ToolType.selection && isObjectSelected) {
      return Row(
        children: [
          const Text("Selection:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Selected Object(s)',
            onPressed: () => notifier.deleteSelectedObjects(whiteBoard),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, color: Colors.black54),
            tooltip: 'Duplicate Selected Object(s)',
            onPressed: () => notifier.duplicateSelectedObjects(whiteBoard),
          ),
          const SizedBox(width: 10), // Reduced for mobile fit
          if(isDesktop) const Text("Stroke: "),
          Tooltip(
            message: 'Set Stroke Color',
            child: InkWell(
              onTap: () => DialogBoxes.showSelectedObjectColorPicker(context, ref, whiteBoard, 'color'),
              child: _buildColorCircleIcon(Icons.format_paint_outlined),
            ),
          ),
          const SizedBox(width: 10),
          if(isDesktop) const Text("Fill: "),
           Tooltip(
            message: 'Set Fill Color',
            child: InkWell(
              onTap: () => DialogBoxes.showSelectedObjectColorPicker(context, ref, whiteBoard, 'fillColor'),
              child: _buildColorCircleIcon(Icons.format_color_fill_outlined),
            ),
          ),
        ],
      );
    }

    // --- DRAWING Properties (Pencil, Shapes, Text, etc.) ---
    if ([
      ToolType.pencil, ToolType.rectangle, ToolType.circle,
      ToolType.line, ToolType.arrow, ToolType.text
    ].contains(activeTool)) {
       // Shared logic for both Mobile and Desktop (Mobile uses this widget inside the row)
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDesktop) ...[
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Text("Properties:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              ),
              SizedBox(
                width: 150,
                child: Slider(
                  value: options.strokeWidth,
                  activeColor: Colors.blue,
                  min: 1,
                  max: 16,
                  divisions: 15,
                  onChanged: (v) => optionsNotifier.state = options.copyWith(strokeWidth: v),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text(
                  options.strokeWidth.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 20),
              const Text("Color: "),
            ],
            
            // Stroke Color
            Tooltip(
              message: 'Select Stroke Color',
              child: InkWell(
                onTap: () => DialogBoxes.showColorPicker(context, ref, 'color'),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Helpers.colorFromHex(options.color),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            
            // Fill Color (Shapes only)
            if ([ToolType.rectangle, ToolType.circle].contains(activeTool)) ...[
              if(isDesktop) const Text("Fill: "),
              Tooltip(
                message: 'Select Fill Color',
                child: InkWell(
                  onTap: () => DialogBoxes.showColorPicker(context, ref, 'fillColor'),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Helpers.colorFromHex(options.fillColor),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            
            // Mobile Specific: Stroke Width Trigger
            if (!isDesktop)
               GestureDetector(
                onTap: () => DialogBoxes.showStrokeWidthSelector(context, ref),
                child: Container(
                  width: 32,
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
        );
    }

    // --- ERASER Properties ---
    if (activeTool == ToolType.eraser) {
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           if (isDesktop)
             const Padding(
               padding: EdgeInsets.only(right: 10),
               child: Text("Eraser:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
             ),
           IconButton(
             icon: Icon(
               Icons.show_chart,
               color: options.eraserMode == EraserMode.stroke ? const Color(0xFF55B8B9) : Colors.black54,
             ),
             tooltip: 'Erase by object/stroke',
             onPressed: () => optionsNotifier.state = options.copyWith(eraserMode: EraserMode.stroke),
           ),
           IconButton(
             icon: Icon(
               Icons.brush,
               color: options.eraserMode == EraserMode.pixel ? const Color(0xFF55B8B9) : Colors.black54,
             ),
             tooltip: 'Pixel eraser',
             onPressed: () => optionsNotifier.state = options.copyWith(eraserMode: EraserMode.pixel),
           ),
           const SizedBox(width: 10),
           
           if (isDesktop) ...[
             SizedBox(
               width: 150,
               child: Slider(
                 value: options.eraserSize,
                 activeColor: Colors.grey,
                 min: 5,
                 max: 50,
                 divisions: 9,
                 onChanged: (v) => optionsNotifier.state = options.copyWith(eraserSize: v),
               ),
             ),
             const SizedBox(width: 10),
             SizedBox(
               width: 30,
               child: Text(
                 options.eraserSize.toStringAsFixed(0),
                 style: const TextStyle(fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
             ),
           ] else ...[
             // Mobile Eraser Size Selector
             GestureDetector(
               onTap: () => DialogBoxes.showEraserSizeSelector(context, ref),
               child: Container(
                 width: 32,
                 height: 32,
                 decoration: BoxDecoration(
                   border: Border.all(color: Colors.black, width: 1.0),
                   borderRadius: BorderRadius.circular(5),
                 ),
                 child: Center(
                   child: Text(
                     options.eraserSize.round().toString(),
                     style: const TextStyle(fontSize: 12),
                   ),
                 ),
               ),
             ),
           ],
         ],
       );
    }

    return const SizedBox.shrink();
  }
  
  Widget _buildColorCircleIcon(IconData icon) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black45, width: 2),
      ),
      child: Icon(icon, size: 16),
    );
  }
}

class SlideManagerWidget extends ConsumerWidget {
  final WhiteBoard whiteBoard;

  const SlideManagerWidget({super.key, required this.whiteBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(activeBoardHistoryProvider(whiteBoard));
    final activeBoard = history.currentBoard;
    final notifier = ref.read(activeBoardHistoryProvider(whiteBoard).notifier);
    final currentSlideIndex = activeBoard.currentSlideIndex;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SLIDES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Divider(height: 10),
          Expanded(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: activeBoard.slides.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                notifier.moveSlide(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final isSelected = index == currentSlideIndex;
                final slide = activeBoard.slides[index];
                return Card(
                  key: ValueKey(activeBoard.slides[index].id),
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  color: isSelected ? const Color(0xFF55B8B9) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => notifier.changeSlide(index),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: SlideThumbnailCanvas(
                              slide: slide,
                              width: 130,
                              height: 78,
                            ),
                          ),
                          Align(
                            alignment: AlignmentGeometry.bottomRight,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              onPressed: () {
                                if (activeBoard.slides.length > 1) {
                                  notifier.deleteSlide(index);
                                } else {
                                  DialogBoxes.showWarningDialog(
                                    context,
                                    message: "Atleast one slide needed Or WhiteBoard will be deleted on 'OK'",
                                    onConfirm: () {
                                      ref.read(whiteBoardListProvider.notifier).deleteBoard(activeBoard.id);
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
                  ),
                );
              },
            ),
          ),
          _GradientButton(
            onPressed: notifier.addSlide,
            label: 'Add Slide',
            icon: Icons.add,
            gradient: const LinearGradient(colors: [Color(0xFFD48FFC), Color(0xFFA671FF)]),
          ),
        ],
      ),
    );
  }
}

class ToolIconWidget extends StatelessWidget {
  final ToolType type;
  const ToolIconWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      ToolType.selection => const Icon(Icons.touch_app_outlined, color: Colors.white),
      ToolType.pan => const Icon(Icons.pan_tool_outlined, color: Colors.white),
      ToolType.pencil => const Icon(Icons.brush_outlined, color: Colors.white),
      ToolType.eraser => const Icon(Icons.cleaning_services_outlined, color: Colors.white),
      ToolType.rectangle => const Icon(Icons.crop_square, color: Colors.white),
      ToolType.circle => const Icon(Icons.circle_outlined, color: Colors.white),
      ToolType.arrow => const Icon(Icons.arrow_forward_rounded, color: Colors.white),
      ToolType.line => const Icon(Icons.horizontal_rule_rounded, color: Colors.white),
      ToolType.text => const Icon(Icons.text_fields_outlined, color: Colors.white),
      ToolType.image => const Icon(Icons.image_outlined, color: Colors.white),
    };
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Gradient gradient;

  const _GradientButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: gradient,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 4, offset: const Offset(0, 2)),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}