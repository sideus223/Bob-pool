import 'package:flutter/material.dart';
import '../models/menu_model.dart';

class RecipePage extends StatelessWidget {
  const RecipePage({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = ModalRoute.of(context)!.settings.arguments as MenuModel?;
    final ingredients = menu?.ingredients ?? const <String>[];
    final steps = menu?.recipeSteps ?? const <String>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${menu?.name ?? "메뉴"} 레시피',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF32201C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (menu != null) ...[
              Text(
                [
                  menu.servings,
                  menu.cookTime,
                  menu.difficulty,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              '재료 준비',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF32201C),
              ),
            ),
            const SizedBox(height: 16),
            if (ingredients.isEmpty)
              const Text('등록된 재료 정보가 없습니다.')
            else
              ...ingredients.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Color(0xFFFD5D69),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item, style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            const Text(
              '조리 순서',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF32201C),
              ),
            ),
            const SizedBox(height: 16),
            if (steps.isEmpty)
              const Text('등록된 조리 순서가 없습니다.')
            else
              ...steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC6C9),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFD5D69),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC6C9).withAlpha(50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFC6C9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFFD5D69)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      menu?.cookingTip.isNotEmpty == true
                          ? menu!.cookingTip
                          : '레시피는 데이터셋 기준 조리 예시입니다.',
                      style: const TextStyle(
                        color: Color(0xFF32201C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
