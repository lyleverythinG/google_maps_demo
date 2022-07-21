import 'dart:async';
import 'dart:typed_data';
import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;

import '../models/auto_complete.dart';
import '../providers/search_places.dart';
import '../services/map_services.dart';

class Home extends ConsumerStatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<Home> {
  final Completer<GoogleMapController> _controller = Completer();
  Timer? _debounce;

//Toggling UI
  bool searchToggle = false;
  bool radiusSlider = false;
  bool cardTapped = false;
  bool pressedNear = false;
  bool getDirections = false;

//Markers
  Set<Marker> _markers = <Marker>{};
  Set<Marker> markersDupe = <Marker>{};

  Set<Polyline> _polylines = <Polyline>{};
  int markerIdCounter = 1;
  int polylineIdCounter = 1;

  var radiusValue = 3000.0;

  LatLng? tappedPoint;

  List allFavoritePlaces = [];

  String tokenKey = '';

  //Page controller
  late PageController _pageController;
  int prevPage = 0;
  Map<String, dynamic>? tappedPlaceDetail;
  String placeImg = '';
  var photoGalleryIndex = 0;
  bool showBlankCard = false;
  bool isReviews = true;
  bool isPhotos = false;
//api key from google cloud console.
  final key = 'your_api_key';

//Circle
  Set<Circle> _circles = <Circle>{};

//Text Editing Controllers
  TextEditingController searchController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

//Initial map position on load
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(10.266053449631428, 123.84235860803098),
    zoom: 14.4746,
  );

  void _setMarker({required point}) {
    var counter = markerIdCounter++;

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setPolyline({required List<PointLatLng> points}) {
    final String polylineIdVal = 'polyline_$polylineIdCounter';

    polylineIdCounter++;

    _polylines.add(Polyline(
        polylineId: PolylineId(polylineIdVal),
        width: 2,
        color: Colors.blue,
        points: points.map((e) => LatLng(e.latitude, e.longitude)).toList()));
  }

  void _setCircle({required LatLng point}) async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: 12)));
    setState(() {
      _circles.add(Circle(
          circleId: const CircleId('circleId'),
          center: point,
          fillColor: Colors.blue.withOpacity(0.1),
          radius: radiusValue,
          strokeColor: Colors.blue,
          strokeWidth: 1));
      getDirections = false;
      searchToggle = false;
      radiusSlider = true;
    });
  }

  _setNearMarker(
      {required LatLng point,
      required String name,
      required List types,
      required String status}) async {
    var counter = markerIdCounter++;

    final Uint8List markerIcon;
    if (types.contains('restaurants')) {
      markerIcon = await getBytesFromAsset(
          path: 'assets/mapicons/restaurants.png', width: 80);
    } else if (types.contains('food')) {
      markerIcon =
          await getBytesFromAsset(path: 'assets/mapicons/food.png', width: 80);
    } else if (types.contains('school')) {
      markerIcon = await getBytesFromAsset(
          path: 'assets/mapicons/schools.png', width: 80);
    } else if (types.contains('bar')) {
      markerIcon =
          await getBytesFromAsset(path: 'assets/mapicons/bars.png', width: 80);
    } else if (types.contains('lodging')) {
      markerIcon = await getBytesFromAsset(
          path: 'assets/mapicons/hotels.png', width: 80);
    } else if (types.contains('store')) {
      markerIcon = await getBytesFromAsset(
          path: 'assets/mapicons/retail-stores.png', width: 80);
    } else if (types.contains('locality')) {
      markerIcon = await getBytesFromAsset(
          path: 'assets/mapicons/local-services.png', width: 80);
    } else {
      markerIcon = await getBytesFromAsset(
          path: 'assets/mapicons/places.png', width: 80);
    }

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        onTap: () {},
        icon: BitmapDescriptor.fromBytes(markerIcon));

    setState(() {
      _markers.add(marker);
    });
  }

  Future<Uint8List> getBytesFromAsset(
      {required String path, required int width}) async {
    ByteData data = await rootBundle.load(path);

    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  @override
  void initState() {
    _pageController = PageController(initialPage: 1, viewportFraction: 0.85)
      ..addListener(_onScroll);
    super.initState();
  }

  void _onScroll() {
    if (_pageController.page!.toInt() != prevPage) {
      prevPage = _pageController.page!.toInt();
      cardTapped = false;
      photoGalleryIndex = 1;
      showBlankCard = false;
      goToTappedPlace();
      fetchImage();
    }
  }

  //Fetch image to place inside the tile in the pageView
  void fetchImage() async {
    if (_pageController.page != null) {
      if (allFavoritePlaces[_pageController.page!.toInt()]['photos'] != null) {
        setState(() {
          placeImg = allFavoritePlaces[_pageController.page!.toInt()]['photos']
              [0]['photo_reference'];
        });
      } else {
        placeImg = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    //Providers
    final allSearchResults = ref.watch(placeResultsProvider);
    final searchFlag = ref.watch(searchToggleProvider);

    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SizedBox(
                    height: screenHeight,
                    width: screenWidth,
                    child: GoogleMap(
                      mapType: MapType.normal,
                      markers: _markers,
                      polylines: _polylines,
                      circles: _circles,
                      initialCameraPosition: _kGooglePlex,
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                      },
                      onTap: (point) {
                        tappedPoint = point;
                        _setCircle(point: point);
                      },
                    ),
                  ),
                  searchToggle
                      ? Padding(
                          padding:
                              const EdgeInsets.fromLTRB(15.0, 40.0, 15.0, 5.0),
                          child: Column(children: [
                            Container(
                              height: 50.0,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Colors.white,
                              ),
                              child: TextFormField(
                                controller: searchController,
                                decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 15.0),
                                    border: InputBorder.none,
                                    hintText: 'Search',
                                    suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            searchToggle = false;

                                            searchController.text = '';
                                            _markers = {};
                                            if (searchFlag.searchToggle) {
                                              searchFlag.toggleSearch();
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.close))),
                                onChanged: (value) {
                                  if (_debounce?.isActive ?? false) {
                                    _debounce?.cancel();
                                  }
                                  _debounce =
                                      Timer(const Duration(milliseconds: 700),
                                          () async {
                                    if (value.length > 2) {
                                      if (!searchFlag.searchToggle) {
                                        searchFlag.toggleSearch();
                                        _markers = {};
                                      }

                                      List<AutoCompleteResult> searchResults =
                                          await MapServices()
                                              .searchPlaces(searchInput: value);

                                      allSearchResults.setResults(
                                          allPlaces: searchResults);
                                    } else {
                                      List<AutoCompleteResult> emptyList = [];
                                      allSearchResults.setResults(
                                          allPlaces: emptyList);
                                    }
                                  });
                                },
                              ),
                            )
                          ]),
                        )
                      : Container(),
                  searchFlag.searchToggle
                      ? allSearchResults.allReturnedResults.isNotEmpty
                          ? Positioned(
                              top: 100.0,
                              left: 15.0,
                              child: Container(
                                height: 200.0,
                                width: screenWidth - 30.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.0),
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                child: ListView(
                                  children: [
                                    ...allSearchResults.allReturnedResults.map(
                                        (e) => buildListItem(e, searchFlag))
                                  ],
                                ),
                              ))
                          : Positioned(
                              top: 100.0,
                              left: 15.0,
                              child: Container(
                                height: 200.0,
                                width: screenWidth - 30.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.0),
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                child: Center(
                                  child: Column(children: [
                                    const Text('No results to show',
                                        style: TextStyle(
                                            fontFamily: 'WorkSans',
                                            fontWeight: FontWeight.w400)),
                                    const SizedBox(height: 5.0),
                                    SizedBox(
                                      width: 125.0,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          searchFlag.toggleSearch();
                                        },
                                        child: const Center(
                                          child: Text(
                                            'Close this',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'WorkSans',
                                                fontWeight: FontWeight.w300),
                                          ),
                                        ),
                                      ),
                                    )
                                  ]),
                                ),
                              ))
                      : Container(),
                  getDirections
                      ? Padding(
                          padding:
                              const EdgeInsets.fromLTRB(15.0, 40.0, 15.0, 5),
                          child: Column(children: [
                            Container(
                              height: 50.0,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Colors.white,
                              ),
                              child: TextFormField(
                                controller: _originController,
                                decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 15.0),
                                    border: InputBorder.none,
                                    hintText: 'Origin'),
                              ),
                            ),
                            const SizedBox(height: 3.0),
                            Container(
                              height: 50.0,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.0),
                                color: Colors.white,
                              ),
                              child: TextFormField(
                                controller: _destinationController,
                                decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 15.0),
                                    border: InputBorder.none,
                                    hintText: 'Destination',
                                    suffixIcon: SizedBox(
                                        width: 96.0,
                                        child: Row(
                                          children: [
                                            IconButton(
                                                onPressed: () async {
                                                  var directions = await MapServices()
                                                      .getDirections(
                                                          origin:
                                                              _originController
                                                                  .text,
                                                          destination:
                                                              _destinationController
                                                                  .text);
                                                  _markers = {};
                                                  _polylines = {};
                                                  gotoPlace(
                                                      directions[
                                                              'start_location']
                                                          ['lat'],
                                                      directions[
                                                              'start_location']
                                                          ['lng'],
                                                      directions['end_location']
                                                          ['lat'],
                                                      directions['end_location']
                                                          ['lng'],
                                                      directions['bounds_ne'],
                                                      directions['bounds_sw']);
                                                  _setPolyline(
                                                      points: directions[
                                                          'polyline_decoded']);
                                                },
                                                icon: const Icon(Icons.search)),
                                            IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    getDirections = false;
                                                    _originController.text = '';
                                                    _destinationController
                                                        .text = '';
                                                    _markers = {};
                                                    _polylines = {};
                                                  });
                                                },
                                                icon: const Icon(Icons.close))
                                          ],
                                        ))),
                              ),
                            )
                          ]),
                        )
                      : Container(),
                  radiusSlider
                      ? Padding(
                          padding:
                              const EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 0.0),
                          child: Container(
                            height: 50.0,
                            color: Colors.black.withOpacity(0.2),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Slider(
                                        activeColor: Colors.black87,
                                        max: 7000.0,
                                        min: 1000.0,
                                        value: radiusValue,
                                        onChanged: (newVal) {
                                          radiusValue = newVal;
                                          pressedNear = false;
                                          _setCircle(point: tappedPoint!);
                                        })),
                                !pressedNear
                                    ? IconButton(
                                        onPressed: () {
                                          if (_debounce?.isActive ?? false) {
                                            _debounce?.cancel();
                                          }
                                          _debounce =
                                              Timer(const Duration(seconds: 2),
                                                  () async {
                                            var placesResult =
                                                await MapServices()
                                                    .getPlaceDetails(
                                                        pos: tappedPoint!,
                                                        radius: radiusValue
                                                            .toInt());

                                            List<dynamic> placesWithin =
                                                placesResult['results'] as List;

                                            allFavoritePlaces = placesWithin;

                                            tokenKey = placesResult[
                                                    'next_page_token'] ??
                                                'none';
                                            _markers = {};
                                            for (var element in placesWithin) {
                                              _setNearMarker(
                                                point: LatLng(
                                                    element['geometry']
                                                        ['location']['lat'],
                                                    element['geometry']
                                                        ['location']['lng']),
                                                name: element['name'],
                                                types: element['types'],
                                                status: element[
                                                        'business_status'] ??
                                                    'not available',
                                              );
                                            }
                                            markersDupe = _markers;
                                            pressedNear = true;
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.near_me,
                                          color: Colors.black87,
                                        ))
                                    : IconButton(
                                        onPressed: () {
                                          if (_debounce?.isActive ?? false) {
                                            _debounce?.cancel();
                                          }
                                          _debounce =
                                              Timer(const Duration(seconds: 2),
                                                  () async {
                                            if (tokenKey != 'none') {
                                              var placesResult =
                                                  await MapServices()
                                                      .getMorePlaceDetails(
                                                          token: tokenKey);

                                              List<dynamic> placesWithin =
                                                  placesResult['results']
                                                      as List;

                                              allFavoritePlaces
                                                  .addAll(placesWithin);

                                              tokenKey = placesResult[
                                                      'next_page_token'] ??
                                                  'none';

                                              for (var element
                                                  in placesWithin) {
                                                _setNearMarker(
                                                  point: LatLng(
                                                      element['geometry']
                                                          ['location']['lat'],
                                                      element['geometry']
                                                          ['location']['lng']),
                                                  name: element['name'],
                                                  types: element['types'],
                                                  status: element[
                                                          'business_status'] ??
                                                      'not available',
                                                );
                                              }
                                            } else {
                                              debugPrint(
                                                  'no more place details');
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.add_location_alt,
                                            size: 30, color: Colors.black87),
                                      ),
                                IconButton(
                                    onPressed: () {
                                      setState(() {
                                        radiusSlider = false;
                                        pressedNear = false;
                                        cardTapped = false;
                                        radiusValue = 3000.0;
                                        _circles = {};
                                        _markers = {};
                                        allFavoritePlaces = [];
                                      });
                                    },
                                    icon: const Icon(Icons.close,
                                        color: Colors.red))
                              ],
                            ),
                          ),
                        )
                      : Container(),
                  pressedNear
                      ? Positioned(
                          bottom: 20.0,
                          child: SizedBox(
                            height: 200.0,
                            width: MediaQuery.of(context).size.width,
                            child: PageView.builder(
                                controller: _pageController,
                                itemCount: allFavoritePlaces.length,
                                itemBuilder: (BuildContext context, int index) {
                                  return _nearbyPlacesList(index);
                                }),
                          ))
                      : Container(),
                  cardTapped
                      ? Positioned(
                          top: 100.0,
                          left: 15.0,
                          child: FlipCard(
                            front: Container(
                              height: 250.0,
                              width: 175.0,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8.0))),
                              child: SingleChildScrollView(
                                child: Column(children: [
                                  Container(
                                    height: 150.0,
                                    width: 175.0,
                                    decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8.0),
                                          topRight: Radius.circular(8.0),
                                        ),
                                        image: DecorationImage(
                                            image: NetworkImage(placeImg != ''
                                                ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$placeImg&key=$key'
                                                : 'https://pic.onlinewebfonts.com/svg/img_546302.png'),
                                            fit: BoxFit.cover)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(7.0),
                                    width: 175.0,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Address: ',
                                          style: TextStyle(
                                              fontFamily: 'WorkSans',
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        SizedBox(
                                            width: 105.0,
                                            child: Text(
                                              tappedPlaceDetail![
                                                      'formatted_address'] ??
                                                  'none given',
                                              style: const TextStyle(
                                                  fontFamily: 'WorkSans',
                                                  fontSize: 11.0,
                                                  fontWeight: FontWeight.w400),
                                            ))
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        7.0, 0.0, 7.0, 0.0),
                                    width: 175.0,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Contact: ',
                                          style: TextStyle(
                                              fontFamily: 'WorkSans',
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        SizedBox(
                                            width: 105.0,
                                            child: Text(
                                              tappedPlaceDetail![
                                                      'formatted_phone_number'] ??
                                                  'none given',
                                              style: const TextStyle(
                                                  fontFamily: 'WorkSans',
                                                  fontSize: 11.0,
                                                  fontWeight: FontWeight.w400),
                                            ))
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            back: Container(
                              height: 300.0,
                              width: 225.0,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(8.0)),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              isReviews = true;
                                              isPhotos = false;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 700),
                                            curve: Curves.easeIn,
                                            padding: const EdgeInsets.fromLTRB(
                                                7.0, 4.0, 7.0, 4.0),
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(11.0),
                                                color: isReviews
                                                    ? Colors.green.shade300
                                                    : Colors.white),
                                            child: Text(
                                              'Reviews',
                                              style: TextStyle(
                                                  color: isReviews
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontFamily: 'WorkSans',
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              isReviews = false;
                                              isPhotos = true;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 700),
                                            curve: Curves.easeIn,
                                            padding: const EdgeInsets.fromLTRB(
                                                7.0, 4.0, 7.0, 4.0),
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(11.0),
                                                color: isPhotos
                                                    ? Colors.green.shade300
                                                    : Colors.white),
                                            child: Text(
                                              'Photos',
                                              style: TextStyle(
                                                  color: isPhotos
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontFamily: 'WorkSans',
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 250.0,
                                    child: isReviews
                                        ? ListView(
                                            children: [
                                              if (isReviews &&
                                                  tappedPlaceDetail![
                                                          'reviews'] !=
                                                      null)
                                                ...tappedPlaceDetail![
                                                        'reviews']!
                                                    .map((e) {
                                                  return _buildReviewItem(e);
                                                })
                                            ],
                                          )
                                        : _buildPhotoGallery(
                                            tappedPlaceDetail!['photos'] ?? []),
                                  )
                                ],
                              ),
                            ),
                          ))
                      : Container()
                ],
              ),
            )
          ],
        ),
        floatingActionButton: FabCircularMenu(
            alignment: Alignment.bottomLeft,
            fabColor: Colors.blue.shade50,
            fabOpenColor: Colors.red.shade100,
            ringDiameter: 250.0,
            ringWidth: 60.0,
            ringColor: Colors.blue.shade50,
            fabSize: 60.0,
            children: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      searchToggle = true;
                      radiusSlider = false;
                      pressedNear = false;
                      cardTapped = false;
                      getDirections = false;
                    });
                  },
                  icon: const Icon(Icons.search)),
              IconButton(
                  onPressed: () {
                    setState(() {
                      searchToggle = false;
                      radiusSlider = false;
                      pressedNear = false;
                      cardTapped = false;
                      getDirections = true;
                    });
                  },
                  icon: const Icon(Icons.navigation))
            ]),
      ),
    );
  }

  _buildReviewItem(review) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
          child: Row(
            children: [
              Container(
                height: 35.0,
                width: 35.0,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                        image: NetworkImage(review['profile_photo_url']),
                        fit: BoxFit.cover)),
              ),
              const SizedBox(width: 4.0),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 160.0,
                  child: Text(
                    review['author_name'],
                    style: const TextStyle(
                        fontFamily: 'WorkSans',
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 3.0),
                RatingStars(
                  value: review['rating'] * 1.0,
                  starCount: 5,
                  starSize: 15,
                  valueLabelColor: const Color(0xff9b9b9b),
                  valueLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'WorkSans',
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      fontSize: 15.0),
                  valueLabelRadius: 7,
                  maxValue: 5,
                  starSpacing: 2,
                  maxValueVisibility: false,
                  valueLabelVisibility: true,
                  animationDuration: const Duration(milliseconds: 1000),
                  valueLabelPadding:
                      const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                  valueLabelMargin: const EdgeInsets.only(right: 4),
                  starOffColor: const Color(0xffe7e8ea),
                  starColor: Colors.yellow,
                )
              ])
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            child: Text(
              review['text'],
              style: const TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w400),
            ),
          ),
        ),
        Divider(color: Colors.grey.shade600, height: 1.0)
      ],
    );
  }

  _buildPhotoGallery(photoElement) {
    if (photoElement == null || photoElement.length == 0) {
      showBlankCard = true;
      return const SizedBox(
        child: Center(
          child: Text(
            'No Photos',
            style: TextStyle(
                fontFamily: 'WorkSans',
                fontSize: 12.0,
                fontWeight: FontWeight.w500),
          ),
        ),
      );
    } else {
      var placeImg = photoElement[photoGalleryIndex]['photo_reference'];
      var maxWidth = photoElement[photoGalleryIndex]['width'];
      var maxHeight = photoElement[photoGalleryIndex]['height'];
      var tempDisplayIndex = photoGalleryIndex + 1;

      return Column(
        children: [
          const SizedBox(height: 10.0),
          Container(
              height: 200.0,
              width: 200.0,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  image: DecorationImage(
                      image: NetworkImage(
                          'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&maxheight=$maxHeight&photo_reference=$placeImg&key=$key'),
                      fit: BoxFit.cover))),
          const SizedBox(height: 10.0),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  if (photoGalleryIndex != 0) {
                    photoGalleryIndex = photoGalleryIndex - 1;
                  } else {
                    photoGalleryIndex = 0;
                  }
                });
              },
              child: Container(
                width: 40.0,
                height: 20.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.0),
                    color: photoGalleryIndex != 0
                        ? Colors.green.shade500
                        : Colors.grey.shade500),
                child: const Center(
                  child: Text(
                    'Prev',
                    style: TextStyle(
                        fontFamily: 'WorkSans',
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            Text(
              '$tempDisplayIndex/' + photoElement.length.toString(),
              style: const TextStyle(
                  fontFamily: 'WorkSans',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (photoGalleryIndex != photoElement.length - 1) {
                    photoGalleryIndex = photoGalleryIndex + 1;
                  } else {
                    photoGalleryIndex = photoElement.length - 1;
                  }
                });
              },
              child: Container(
                width: 40.0,
                height: 20.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.0),
                    color: photoGalleryIndex != photoElement.length - 1
                        ? Colors.green.shade500
                        : Colors.grey.shade500),
                child: const Center(
                  child: Text(
                    'Next',
                    style: TextStyle(
                        fontFamily: 'WorkSans',
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ])
        ],
      );
    }
  }

  gotoPlace(double lat, double lng, double endLat, double endLng,
      Map<String, dynamic> boundsNe, Map<String, dynamic> boundsSw) async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(boundsSw['lat'], boundsSw['lng']),
            northeast: LatLng(boundsNe['lat'], boundsNe['lng'])),
        25));

    _setMarker(point: LatLng(lat, lng));
    _setMarker(point: LatLng(endLat, endLng));
  }

  Future<void> moveCameraSlightly() async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
            allFavoritePlaces[_pageController.page!.toInt()]['geometry']
                    ['location']['lat'] +
                0.0125,
            allFavoritePlaces[_pageController.page!.toInt()]['geometry']
                    ['location']['lng'] +
                0.005),
        zoom: 14.0,
        bearing: 45.0,
        tilt: 45.0)));
  }

  _nearbyPlacesList(index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (BuildContext context, Widget? widget) {
        double value = 1;
        if (_pageController.position.haveDimensions) {
          value = (_pageController.page! - index);
          value = (1 - (value.abs() * 0.3) + 0.06).clamp(0.0, 1.0);
        }
        return Center(
          child: SizedBox(
            height: Curves.easeInOut.transform(value) * 125.0,
            width: Curves.easeInOut.transform(value) * 350.0,
            child: widget,
          ),
        );
      },
      child: InkWell(
        onTap: () async {
          cardTapped = !cardTapped;
          if (cardTapped) {
            tappedPlaceDetail = await MapServices()
                .getPlace(allFavoritePlaces[index]['place_id']);
            setState(() {});
          }
          moveCameraSlightly();
        },
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 20.0,
                ),
                height: 125.0,
                width: 275.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          offset: Offset(0.0, 4.0),
                          blurRadius: 10.0)
                    ]),
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      color: Colors.white),
                  child: Row(
                    children: [
                      _pageController.position.haveDimensions
                          ? _pageController.page!.toInt() == index
                              ? Container(
                                  height: 90.0,
                                  width: 90.0,
                                  decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10.0),
                                        topLeft: Radius.circular(10.0),
                                      ),
                                      image: DecorationImage(
                                          image: NetworkImage(placeImg != ''
                                              ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$placeImg&key=$key'
                                              : 'https://pic.onlinewebfonts.com/svg/img_546302.png'),
                                          fit: BoxFit.cover)),
                                )
                              : Container(
                                  height: 90.0,
                                  width: 20.0,
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(10.0),
                                        topLeft: Radius.circular(10.0),
                                      ),
                                      color: Colors.black87),
                                )
                          : Container(),
                      const SizedBox(width: 5.0),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 170.0,
                            child: Text(allFavoritePlaces[index]['name'],
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontFamily: 'WorkSans',
                                    fontWeight: FontWeight.bold)),
                          ),
                          RatingStars(
                            value: allFavoritePlaces[index]['rating']
                                        .runtimeType ==
                                    int
                                ? allFavoritePlaces[index]['rating'] * 1.0
                                : allFavoritePlaces[index]['rating'] ?? 0.0,
                            starCount: 5,
                            starSize: 10,
                            valueLabelColor: const Color(0xff9b9b9b),
                            valueLabelTextStyle: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'WorkSans',
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                fontSize: 12.0),
                            valueLabelRadius: 10,
                            maxValue: 5,
                            starSpacing: 2,
                            maxValueVisibility: false,
                            valueLabelVisibility: true,
                            animationDuration:
                                const Duration(milliseconds: 1000),
                            valueLabelPadding: const EdgeInsets.symmetric(
                                vertical: 1, horizontal: 8),
                            valueLabelMargin: const EdgeInsets.only(right: 8),
                            starOffColor: const Color(0xffe7e8ea),
                            starColor: Colors.yellow,
                          ),
                          SizedBox(
                            width: 170.0,
                            child: Text(
                              allFavoritePlaces[index]['business_status'] ??
                                  'none',
                              style: TextStyle(
                                  color: allFavoritePlaces[index]
                                              ['business_status'] ==
                                          'OPERATIONAL'
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> goToTappedPlace() async {
    final GoogleMapController controller = await _controller.future;

    _markers = {};

    var selectedPlace = allFavoritePlaces[_pageController.page!.toInt()];

    _setNearMarker(
        point: LatLng(selectedPlace['geometry']['location']['lat'],
            selectedPlace['geometry']['location']['lng']),
        name: selectedPlace['name'] ?? 'no name',
        types: selectedPlace['types'],
        status: selectedPlace['business_status'] ?? 'none');

    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(selectedPlace['geometry']['location']['lat'],
            selectedPlace['geometry']['location']['lng']),
        zoom: 14.0,
        bearing: 45.0,
        tilt: 45.0)));
  }

  Future<void> gotoSearchedPlace(double lat, double lng) async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 12)));

    _setMarker(point: LatLng(lat, lng));
  }

  Widget buildListItem(AutoCompleteResult placeItem, searchFlag) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTapDown: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        onTap: () async {
          var place = await MapServices().getPlace(placeItem.placeId);
          gotoSearchedPlace(place['geometry']['location']['lat'],
              place['geometry']['location']['lng']);
          searchFlag.toggleSearch();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.green, size: 25.0),
            const SizedBox(width: 4.0),
            SizedBox(
              height: 40.0,
              width: MediaQuery.of(context).size.width - 75.0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(placeItem.description ?? ''),
              ),
            )
          ],
        ),
      ),
    );
  }
}
