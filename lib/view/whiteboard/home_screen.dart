import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/whiteboard_models/drawing_objects.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/view/authentication/auth_screen.dart';
import 'package:white_boarding_app/view/whiteboard/white_board_screen.dart';
import 'package:white_boarding_app/view/whiteboard/widgets/board_selection_dialog.dart';
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';
import 'package:white_boarding_app/utils/helpers/dialog_boxes.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    // logic to determine layout type
    final bool isDesktop = size.width > 910;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const HomeAppBar(),
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
        child: _HomeScreenContent(isDesktop: isDesktop),
      ),
    );
  }
}

class _HomeScreenContent extends ConsumerWidget {
  final bool isDesktop;

  const _HomeScreenContent({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteBoards = ref.watch(whiteBoardListProvider);

    // Responsive Grid Calculations
    final size = MediaQuery.of(context).size;
    final crossAxisCount = isDesktop ? 5 : (size.width > 600 ? 3 : 2);

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
          if (isDesktop) const DesktopActionRow(),
          if (!isDesktop) const MobileActionRow(),

          if (!isDesktop) const SizedBox(height: 15),

          // Empty State
          if (whiteBoards.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 50.0),
                child: Image(image: AssetImage("assets/no_whiteboard.png")),
              ),
            ),

          // Grid View
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
                return WhiteBoardCard(
                  whiteBoard: whiteBoards[index],
                  isDesktop: isDesktop,
                );
              },
            ),
        ],
      ),
    );
  }
}

// --- Reusable Component Widgets ---

class HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
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
        if (authState.isAuthenticated && authState.user!.name != "Guest")
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF55B8B9)),
              tooltip: 'Sync Now',
              onPressed: () async {
                // Visual feedback for manual press
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Syncing with cloud..."),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  // Access the notifier and call sync
                  await ref
                      .read(whiteBoardListProvider.notifier)
                      .syncWithBackend();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Sync Complete!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Sync Failed: ${e.toString().split(':').last}",
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        if (authState.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        if (!authState.isLoading && authState.isAuthenticated) ...[
          Center(
            child: Text(
              "Hi, ${authState.user?.name}",
              style: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.account_circle,
              size: 32,
              color: Color(0xFF55B8B9),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                if (authState.user!.name != "Guest") {
                  await authNotifier.logout();
                }
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: "logout",
                  child: Row(
                    children: [
                      !(authState.user?.name == "Guest")
                          ? Icon(Icons.logout)
                          : Icon(Icons.add),
                      SizedBox(width: 8),
                      Text(
                        !(authState.user?.name == "Guest")
                            ? 'Logout'
                            : "Sign up / Sign in",
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],

        // if (!authState.isLoading && !authState.isAuthenticated)
        //   GradientButton(
        //     onPressed: () {
        //         Navigator.of(context).pushAndRemoveUntil(
        //             MaterialPageRoute(builder: (_) => const AuthScreen()),
        //             (Route<dynamic> route) => false,
        //           );
        //     },
        //     label: "Sign Up/Sign In",
        //     icon: Icons.login,
        //     gradient: const LinearGradient(
        //       colors: [Color(0xFF86DAB9), Color(0xFF55B8B9)],
        //     ),
        //   ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class MobileActionRow extends ConsumerWidget {
  const MobileActionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(whiteBoardListProvider.notifier);

    return SizedBox(
      // Used SizedBox instead of PreferredSize as it's inside a body Column
      height: 60.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: GradientButton(
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
              child: GradientButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const BoardSelectionDialog(),
                  );
                },
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
}

class DesktopActionRow extends ConsumerWidget {
  const DesktopActionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(whiteBoardListProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          GradientButton(
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
          GradientButton(
            onPressed: () {
    showDialog(
      context: context,
      builder: (context) => const BoardSelectionDialog(),
    );
  },
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
}

class WhiteBoardCard extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  final bool isDesktop;

  const WhiteBoardCard({
    super.key,
    required this.whiteBoard,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            DialogBoxes.showBoardOptionsDialog(context, ref, whiteBoard, false),
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
              WhiteBoardThumbnail(whiteBoard: whiteBoard, isDesktop: isDesktop),
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
}

class WhiteBoardThumbnail extends StatelessWidget {
  final WhiteBoard whiteBoard;
  final bool isDesktop;

  const WhiteBoardThumbnail({
    super.key,
    required this.whiteBoard,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
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
}

class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Gradient gradient;

  const GradientButton({
    super.key,
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
