import 'package:flutter/material.dart';
import 'package:voyageventure/screens/home_screen.dart';

import '../components/loading_indicator.dart';
import '../components/misc_widget.dart';

class BottomSheetLoading extends StatelessWidget {
  MapData mapData;
  BottomSheetLoading({super.key, required this.mapData});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _dragableController,
      initialChildSize:
      defaultBottomSheetHeight /
          1000,
      minChildSize: 0.15,
      maxChildSize: 1,
      builder: (BuildContext context,
          ScrollController
          scrollController) {
        return ClipRRect(
          borderRadius:
          const BorderRadius.only(
            topLeft:
            Radius.circular(24.0),
            topRight:
            Radius.circular(24.0),
          ),
          child: Container(
            color: Colors.white,
            child:
            SingleChildScrollView(
              primary: false,
              controller:
              scrollController,
              child: Column(
                  children: <Widget>[
                    const Pill(),
                    SizedBox(
                      height: 40,
                    ),
                    LoadingIndicator(
                      color: Colors
                          .green,
                      onPressed: () {
                        mapData.changeState(
                            "Search Results");
                      },
                    ),
                  ]),
            ),
          ),
        );
      },
    )

  }
}
