import 'package:flutter/material.dart';
import '../latestVideoEditorController/videoRecordController.dart';
void showTextInputDialog(BuildContext context, VideoRecordController controller) {
  final TextEditingController textController = TextEditingController();
  Color selectedColor = Colors.white;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.8),
      title: Text('Add Text', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: textController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter text here',
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _colorOption(Colors.white, (color) => selectedColor = color),
                _colorOption(Colors.red, (color) => selectedColor = color),
                _colorOption(Colors.blue, (color) => selectedColor = color),
                _colorOption(Colors.green, (color) => selectedColor = color),
                _colorOption(Colors.yellow, (color) => selectedColor = color),
                _colorOption(Colors.pink, (color) => selectedColor = color),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // controller.updateText(textController.text, selectedColor);
            Navigator.pop(context);
          },
          child: Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Widget _colorOption(Color color, Function(Color) onTap) {
  return GestureDetector(
    onTap: () => onTap(color),
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    ),
  );
}