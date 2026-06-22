# example


Here's a simple application that demonstrates how [CustomNavigator]
works. 
Using a bottom navigation with simple details page.

## Getting Started


give a navigator key to [MaterialApp] if you want to use the default navigation
anywhere in your app eg: line 15 & line 93.
This should be on a global level.

```dart
GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();
```
#### HomePage
``` dart
class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Page _page = Page('Page 0');
  int _currentIndex = 0;

  // Custom navigator takes a global key if you want to access the
  // navigator from outside it's widget tree subtree
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: _items,
        onTap: (index) {
          // here we used the navigator key to pop the stack to get back to our
          // main page
          navigatorKey.currentState.maybePop();
          setState(() => _page = Page('Page $index'));
          _currentIndex = index;
        },
        currentIndex: _currentIndex,
      ),
      body: CustomNavigator(
        navigatorKey: navigatorKey,
        home: _page,
        //Specify your page route [PageRoutes.materialPageRoute] or [PageRoutes.cupertinoPageRoute]
        pageRoute: PageRoutes.materialPageRoute,
      ),
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

    return Container(
      child: Center(
          child: FlatButton(
              onPressed: () => _openDetailsPage(context), child: text)),
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
    return Container(
      child: Center(child: text),
    );
  }
}

```