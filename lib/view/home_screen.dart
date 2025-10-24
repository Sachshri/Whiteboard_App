import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/white_board.dart';
import 'package:white_boarding_app/view/white_board_screen.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';
import 'package:white_boarding_app/widgets/dialog_boxes.dart';
import '../models/drawing_objects.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  PreferredSizeWidget buildCustomAppBar(WidgetRef ref, bool isDesktop) {
    return AppBar(
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      elevation: 0,
      centerTitle: false,
      title: const Text(
        'My White Boards',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      actions: [
        _buildGradientButton(
          onPressed: () => debugPrint("Signup Tapped"),
          label: "Sign Up",
          icon: Icons.person,
          gradient: const LinearGradient(
            colors: [Color(0xFF86DAB9), Color(0xFF55B8B9)],
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  PreferredSizeWidget _buildMobileButtonRow(
    WidgetRef ref,
    BuildContext context,
  ) {
    final notifier = ref.read(whiteBoardListProvider.notifier);
    return PreferredSize(
      preferredSize: const Size.fromHeight(60.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: _buildGradientButton(
                onPressed: () {
                  final WhiteBoard whiteBoard = notifier.createNewWhiteBoard(
                    'Untitled Board',
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          WhiteBoardScreen(whiteBoard: whiteBoard),
                    ),
                  );
                },
                label: 'New Board',
                icon: Icons.edit,
                gradient: const LinearGradient(
                  colors: [Color(0xFF86DAB9), Color(0xFF55B8B9)],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGradientButton(
                onPressed: () => debugPrint('Collaborate tapped'),
                label: 'Collaborate',
                icon: Icons.group,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD48FFC), Color(0xFFA671FF)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteBoards = ref.watch(whiteBoardListProvider);
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 910;
    final crossAxisCount = isDesktop ? 5 : (size.width > 600 ? 3 : 2);

    Widget content() {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 30.0 : 16.0,
          isDesktop ? kToolbarHeight + 30.0 : kToolbarHeight * 2.5,
          isDesktop ? 30.0 : 16.0,
          30.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) _buildDesktopButtons(ref, context),
            if (!isDesktop) _buildMobileButtonRow(ref, context),

            if (!isDesktop) const SizedBox(height: 15),
            // Grid View
            if (whiteBoards.isEmpty)
              Center(
                child: Image(image: AssetImage("assets/no_whiteboard.png")),
              ),
            if (whiteBoards.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: whiteBoards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: isDesktop ? 25 : 10,
                  mainAxisSpacing: isDesktop ? 25 : 10,
                  childAspectRatio: isDesktop ? 1.0 : 0.9,
                ),
                itemBuilder: (context, index) {
                  return _buildWhiteBoardCard(
                    context,
                    whiteBoards[index],
                    ref,
                    isDesktop,
                  );
                },
              ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildCustomAppBar(ref, isDesktop),
      backgroundColor: Colors.transparent,
      body: Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
            opacity: 1.0,
          ),
        ),
        child: content(),
      ),
    );
  }

  Widget _buildThumbnail(WhiteBoard whiteBoard, bool isDesktop) {
    final colorSeed = whiteBoard.id.hashCode;

    IconData icon;
    if (whiteBoard.slides.first.objects.any((obj) => obj is PenObject)) {
      icon = Icons.brush_rounded;
    } else if (whiteBoard.slides.first.objects.any(
      (obj) => obj.type == 'text',
    )) {
      icon = Icons.text_fields;
    } else {
      icon = Icons.wb_incandescent;
    }

    return AspectRatio(
      aspectRatio: 1.618,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              Color(colorSeed).withAlpha(76),
              Color(colorSeed ~/ 2).withAlpha(127),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
        child: Center(
          child: Icon(icon, size: isDesktop ? 40 : 30, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildWhiteBoardCard(
    BuildContext context,
    WhiteBoard whiteBoard,
    WidgetRef ref,
    bool isDesktop,
  ) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: const Color.fromARGB(176, 255, 255, 255),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WhiteBoardScreen(whiteBoard: whiteBoard),
            ),
          );
        },
        onDoubleTap: () =>
            DialogBoxes.showTitleEditDialog(context, ref, whiteBoard,false),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(whiteBoard, isDesktop),
              const SizedBox(height: 8),
              Text(
                whiteBoard.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                whiteBoard.creationDate.replaceAll('-', '/'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 130, 130, 130),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopButtons(WidgetRef ref, BuildContext context) {
    final notifier = ref.read(whiteBoardListProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          _buildGradientButton(
            onPressed: () {
              final WhiteBoard whiteBoard = notifier.createNewWhiteBoard(
                'Untitled Board',
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      WhiteBoardScreen(whiteBoard: whiteBoard),
                ),
              );
            },
            label: 'New Board',
            icon: Icons.edit,
            gradient: const LinearGradient(
              colors: [Color(0xFF86DAB9), Color(0xFF55B8B9)],
            ),
          ),
          const SizedBox(width: 15),
          _buildGradientButton(
            onPressed: () => debugPrint('Collaborate tapped'),
            label: 'Collaborate',
            icon: Icons.group,
            gradient: const LinearGradient(
              colors: [Color(0xFFD48FFC), Color(0xFFA671FF)],
            ),
          ),
        ],
      ),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
