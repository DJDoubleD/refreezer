import 'package:custom_navigator/custom_scaffold.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

//give a navigator key to [MaterialApp] if you want to use the default navigation
//anywhere in your app eg: line 15 & line 93
GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: mainNavigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.pink,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.pink,
        ),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Custom navigator takes a global key if you want to access the
  // navigator from outside it's widget tree subtree
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Here's the custom scaffold widget
    // It takes a normal scaffold with mandatory bottom navigation bar
    // and children who are your pages
    return CustomScaffold(
      scaffold: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          items: _items,
        ),
      ),

      // Children are the pages that will be shown by every click
      // They should placed in order such as
      // `page 0` will be presented when `item 0` in the [BottomNavigationBar] clicked.
      children: const <Widget>[
        Page('0'),
        Page('1'),
        Page('2'),
      ],

      // Called when one of the [items] is tapped.
      onItemTap: (index) {},
    );
  }

  final _items = [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
    const BottomNavigationBarItem(icon: Icon(Icons.event), label: 'events'),
    const BottomNavigationBarItem(
        icon: Icon(Icons.save_alt), label: 'downloads'),
  ];
}

class Page extends StatelessWidget {
  final String? title;

  const Page(this.title, {Key? key})
      : assert(title != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = Text(title ?? '');

    return Scaffold(
      body: Center(
          child: ElevatedButton(
              onPressed: () => _openDetailsPage(context), child: text)),
      appBar: AppBar(
        centerTitle: true,
        title: text,
      ),
    );
  }

  //Use the navigator like you usually do with .of(context) method
  _openDetailsPage(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => DetailsPage(title)));

//  _openDetailsPage(BuildContext context) => mainNavigatorKey.currentState.push(MaterialPageRoute(builder: (context) => DetailsPage(title)));
}

class DetailsPage extends StatelessWidget {
  final String? title;

  const DetailsPage(this.title, {Key? key})
      : assert(title != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = Text('Details of $title');
    return Scaffold(
      body: Center(child: text),
      appBar: AppBar(
        centerTitle: true,
        title: text,
      ),
    );
  }
}
