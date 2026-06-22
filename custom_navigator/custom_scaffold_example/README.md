# custom_scaffold_example

An application that demonstrates how [CustomScaffold] works.

## Getting Started


#### HomePage

```dart
class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
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
      children: <Widget>[
        Page('0'),
        Page('1'),
        Page('2'),
      ],

      // Called when one of the [items] is tapped.
      onItemTap: (index) {},
    );
  }

  final _items = [
    BottomNavigationBarItem(icon: Icon(Icons.home), title: Text('home')),
    BottomNavigationBarItem(icon: Icon(Icons.event), title: Text('events')),
    BottomNavigationBarItem(
        icon: Icon(Icons.save_alt), title: Text('downloads')),
  ];
}
```

#### Page tab
This is the page of each tab in the bottom navigation
```dart
class Page extends StatelessWidget {
  final String title;

  const Page(this.title) : assert(title != null);

  @override
  Widget build(BuildContext context) {
    final text = Text(title);

    return Scaffold(
      body: Container(
        child: Center(
            child: FlatButton(
                onPressed: () => _openDetailsPage(context), child: text)),
      ),
      appBar: AppBar(
        title: text,
      ),
    );
  }

  //Use the navigator like you usually do with .of(context) method
  _openDetailsPage(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => DetailsPage(title)));

//  _openDetailsPage(BuildContext context) => mainNavigatorKey.currentState.push(MaterialPageRoute(builder: (context) => DetailsPage(title)));

}
```

#### Details page
```dart

class DetailsPage extends StatelessWidget {
  final String title;

  const DetailsPage(this.title) : assert(title != null);

  @override
  Widget build(BuildContext context) {
    final text = Text('Details of $title');
    return Scaffold(
      body: Container(
        child: Center(child: text),
      ),
      appBar: AppBar(title: text),
    );
  }
}
```