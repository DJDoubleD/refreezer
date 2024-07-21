import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../translations.i18n.dart';
import 'elements.dart';

class ApplicationLogViewer extends StatefulWidget {
  const ApplicationLogViewer({super.key});

  @override
  _ApplicationLogViewerState createState() => _ApplicationLogViewerState();
}

class _ApplicationLogViewerState extends State<ApplicationLogViewer> {
  List<String> data = [];

  //Load log from file
  Future _load() async {
    String path = p.join((await getExternalStorageDirectory())!.path, 'refreezer.log');
    File file = File(path);
    if (await file.exists()) {
      String d = await file.readAsString();
      setState(() {
        data = d.replaceAll('\r', '').split('\n');
      });
    }
  }

  //Get color by log type
  Color? color(String line) {
    if (line.startsWith('[log] SEVERE:')) return Colors.red;
    if (line.startsWith('[log] WARNING:')) return Colors.orange[600];
    return null;
  }

  @override
  void initState() {
    _load();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: FreezerAppBar('Application Log'.i18n),
        body: ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                data[i],
                style: TextStyle(fontSize: 14.0, color: color(data[i])),
              ),
            );
          },
        ));
  }
}
