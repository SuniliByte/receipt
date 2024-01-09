// ignore_for_file: avoid_print, unused_import, prefer_final_locals

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drago_pos_printer/drago_pos_printer.dart';
import 'package:drago_pos_printer/services/printer_manager.dart';
import 'package:fast_food_app/app/app_constants/string_contants.dart';
import 'package:fast_food_app/app/model/printer_format.dart';
import 'package:fast_food_app/app/model/z_report_model.dart';
import 'package:fast_food_app/app/widgets/custom_show_info.dart';
import 'package:fast_food_app/app/widgets/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart' as esc_pos;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hex/hex.dart';
import 'package:image/image.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:timezone/timezone.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

import '../model/all_order_model.dart';

class PrinterService {
  int? _paperSizeWidthMM;
  int? _maxPerLine;
  CapabilityProfile? _profile;

  String getStringg(String item, String qty, String amount) {
    late int len;
    String res = "";
    if (qty != "") {
      if (qty.length == 1) {
        res += " $qty    ";
      } else if (qty.length == 2) {
        res += " $qty   ";
      } else if (qty.length == 3) {
        res += " $qty  ";
      }
    }
    len = item.length;
    if (qty != "") {
      if (len > 28) {
        res += "${item.substring(0, 24)}... ";
      } else {
        String space = "";
        for (int i = 0; i < (28 - len); i++) {
          space += " ";
        }
        res += item + space;
      }
    } else {
      if (len > 32) {
        res += res += "  ${item.substring(0, 28)}... ";
      } else {
        String space = "";
        for (int i = 0; i < (34 - len); i++) {
          space += " ";
        }
        res += item + space;
      }
    }
    late int lenAm;
    lenAm = amount.length;
    String space2 = "";
    for (int i = 0; i < (12 - lenAm); i++) {
      space2 += " ";
    }
    res += space2 + amount;
    return res;
  }

  getOrderId(String orderId) {
    String res = "";
    res = orderId.split("_").last;
    return res.toString();
  }

  String getRow(String title, String value, {int lines = 37}) {
    String row = "";
    late int titleLen;
    titleLen = title.length;
    late int valueLen;
    valueLen = value.length;
    final spaces = lines - (titleLen + valueLen);
    row = title + " " * spaces + value;
    return row;
  }

  Future<List<int>> dineInBill(
    PData pdata, {
    int paperSizeWidthMM = PaperSizeMaxPerLine.mm80,
    int maxPerLine = PaperSizeMaxPerLine.mm80,
    CapabilityProfile? profile,
    bool reprint = false,
  }) async {
    List<int> bytes = [];
    _profile = profile ?? (await CapabilityProfile.load(name: "default"));
    _paperSizeWidthMM = paperSizeWidthMM;
    _maxPerLine = maxPerLine;
    final ticket = Generator(_paperSizeWidthMM!, _maxPerLine!, _profile!);
    bytes += ticket.reset();
    bytes += ticket.reverseFeed(2);
    bytes += ticket.setGlobalCodeTable('CP1252');
    final logoImage = await ScreenshotController().captureFromWidget(
      CachedNetworkImage(
        imageUrl: LocalStorage()
                .getUserData()!
                .userData!
                .storeData!
                .storeImage!
                .baseUrl! +
            LocalStorage()
                .getUserData()!
                .userData!
                .storeData!
                .storeImage!
                .attachmentUrl!,
        height: 100,
        width: 300,
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
      delay: const Duration(microseconds: 10),
    );
    final logo = decodeImage(logoImage);
    bytes += ticket.image(logo!);
    bytes += ticket.emptyLines(1);
    final controller = ScreenshotController();
    final barWithTableNoImage = await controller.captureFromWidget(
      Stack(
        children: [
          Container(
            height: 50,
            width: 380,
            color: Colors.black,
            child: Center(
              child: Text(
                "TABLE ${pdata.tableNo}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Text(
              DateFormat('hh:mm     ').format(
                DateTime.now(),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            left: 5,
            child: Text(
              "B." + LocalStorage.shared.dineInBillNumber().toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
    final barWithTableNoImageByte = await decodeImage(barWithTableNoImage);
    bytes += ticket.imageRaster(barWithTableNoImageByte!);
    bytes += ticket.emptyLines(1);
    final itemsImage = await controller.captureFromWidget(
      Container(
        width: 380,
        color: Colors.white,
        child: const Row(
          children: [
            Expanded(
              child: Text(
                "  Qty.",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                "Items",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Text(
                "Price",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      delay: const Duration(microseconds: 10),
    );
    final itemsImageByte = await decodeImage(itemsImage);
    bytes += ticket.imageRaster(itemsImageByte!);
    bytes += ticket.emptyLines(1);
    for (final v in pdata.items) {
      final itemImage = await controller.captureFromWidget(
        Container(
          width: 380,
          color: Colors.white,
          padding: const EdgeInsets.only(top: 10, right: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "  " + v.itemQuantity.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  v.variationName != null
                      ? "${v.itemName} (${v.variationName})"
                      : v.itemName,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  "$currencySymbol${double.parse(v.originalPrice).toStringAsFixed(2)}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        delay: const Duration(microseconds: 10),
      );
      final itemImageByte = await decodeImage(itemImage);
      bytes += ticket.imageRaster(itemImageByte!);
      if (v.selectedSteps != null) {
        for (final w in v.selectedSteps!) {
          final stepImage = await controller.captureFromWidget(
            Container(
              // height: 35,
              width: 380,
              padding: const EdgeInsets.only(right: 10),
              color: Colors.white,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      "   " + w.stepName,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        double.parse(w.price) == 0
                            ? "   "
                            : "$currencySymbol${double.parse(w.price).toStringAsFixed(2)}",
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          // fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            delay: const Duration(microseconds: 10),
          );
          final stepImageByte = await decodeImage(stepImage);
          bytes += ticket.imageRaster(stepImageByte!);
        }
      }
      if (v.selectedAddOns != null) {
        for (final w in v.selectedAddOns!) {
          final addonImage = await controller.captureFromWidget(
            Container(
              width: 380,
              color: Colors.white,
              padding: const EdgeInsets.only(top: 10, right: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "  " + w.itemQuantity.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      w.addOnName,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      "$currencySymbol${double.parse(w.price).toStringAsFixed(2)}",
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            delay: const Duration(microseconds: 10),
          );
          final addonImageByte = await decodeImage(addonImage);
          bytes += ticket.imageRaster(addonImageByte!);
        }
      }
    }
    bytes += ticket.emptyLines(1);
    bytes += ticket.emptyLines(1);
    final poweredImage = await controller.captureFromWidget(
      Container(
        height: 45,
        width: 380,
        color: Colors.white,
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              text: "powered by ",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: "FASTFOOD",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      delay: const Duration(microseconds: 10),
    );
    final poweredImagebytes = await decodeImage(poweredImage);
    bytes += ticket.imageRaster(poweredImagebytes!);
    bytes += ticket.emptyLines(2);
    bytes += ticket.cut();
    bytes += ticket.beep(n: 2, duration: PosBeepDuration.beep100ms);
    return bytes;
  }

  double getTotal(PData pdata) {
    double total = 0;
    for (final element in pdata.items) {
      total += double.parse(element.price);
    }
    for (final element in pdata.addamounts) {
      total += double.parse(element['amount'].toString()) *
          int.parse(element['quantity'].toString());
    }
    return total;
  }

  Future<List<int>> zReport(
    ZReportModel data, {
    int paperSizeWidthMM = PaperSizeWidth.mm80,
    int maxPerLine = PaperSizeMaxPerLine.mm80,
    CapabilityProfile? profile,
    String date = "",
  }) async {
    List<int> bytes = [];
    _profile = profile ?? (await CapabilityProfile.load(name: "default"));
    _paperSizeWidthMM = paperSizeWidthMM;
    _maxPerLine = maxPerLine;
    final ticket = Generator(_paperSizeWidthMM!, 37, _profile!);
    bytes += ticket.reset();
    bytes += ticket.reverseFeed(2);
    bytes += ticket.setGlobalCodeTable('CP1252');
    bytes += ticket.rawBytes([29, 40, 69, 3, 0, 6, 20, 128]);
    // bytes += ticket.rawBytes([28, 45, 03, 00, 0614, 129]);
    bytes += ticket.rawBytes([29, 40, 69, 3, 0, 6, 10, 15]);
    bytes += ticket.rawBytes([27, 82, 3]);
    //Logo image
    final storeData = LocalStorage().getUserData()!.userData!.storeData;
    final imageUrl =
        storeData!.storeImage!.baseUrl! + storeData.storeImage!.attachmentUrl!;
    final shouldPrintLogo = LocalStorage.userDataBox.read('printLogo') ?? false;
    if (shouldPrintLogo) {
      if (LocalStorage.userDataBox.hasData('logo')) {
        final storeImageBytes = LocalStorage.userDataBox.read('logo');
        List<int> imageBytes = [];
        jsonDecode(storeImageBytes).forEach((element) {
          imageBytes.add(element);
        });
        final image = decodeImage(
          Uint8List.fromList(imageBytes),
        );
        //Resize image to 150px width and 150px height
        final resizedImage = copyResize(image!, width: 150, height: 150);
        bytes += ticket.image(resizedImage);
      } else {
        final storeImageBytes =
            (await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl))
                .buffer
                .asUint8List();
        LocalStorage.userDataBox.write(
          'logo',
          storeImageBytes.toList().toString(),
        );
        final image = decodeImage(storeImageBytes);
        //Resize image to 150px width and 150px height
        final resizedImage = copyResize(image!, width: 150, height: 150);
        bytes += ticket.image(resizedImage);
      }
    }
    bytes += ticket.emptyLines(1);
    bytes += ticket.text(
      "         Z REPORT        ",
      styles: const PosStyles(
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
        align: PosAlign.center,
        reverse: true,
      ),
    );
    bytes += ticket.emptyLines(1);
    bytes += ticket.text(
      date,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += ticket.text(
      "Sales Summary",
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += ticket.emptyLines(1);

    bytes += ticket.row([
      PosColumn(
        text: "Category",
        styles: const PosStyles(
          bold: true,
        ),
        width: 5,
      ),
      PosColumn(
        text: "Qty",
        styles: const PosStyles(
          bold: true,
        ),
        width: 3,
      ),
      PosColumn(
        text: "Sales  ",
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
        width: 4,
      ),
    ]);
    bytes += ticket.hr(ch: "-", len: 58);

    bytes += ticket.row([
      PosColumn(
        text: "Pickup",
        width: 5,
      ),
      PosColumn(
        text: getQuantity(data.pickupRevenue!.totalQuantity),
        width: 3,
      ),
      PosColumn(
        textEncoded: Uint8List.fromList([
          ...utf8.encode(symbol),
          ...data.pickupRevenue!.totalPrice!
              .toDouble()
              .toStringAsFixed(2)
              .codeUnits,
          ..."  ".codeUnits,
        ]),
        styles: const PosStyles(
          align: PosAlign.right,
        ),
        width: 4,
      ),
    ]);
    bytes += ticket.row(
      [
        PosColumn(
          text: "Dine In",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.dineInRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.dineInRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.row(
      [
        PosColumn(
          text: "Delivery",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.deliveryRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.deliveryRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.row(
      [
        PosColumn(
          text: "Web Delivery",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.webDeliveryRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.webDeliveryRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.row(
      [
        PosColumn(
          text: "Web Pickup",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.webPickupRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.webPickupRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.hr(ch: "-", len: 58);
    bytes += ticket.row(
      [
        PosColumn(
          text: "Total",
          styles: const PosStyles(
            bold: true,
          ),
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.dineInRevenue!.totalQuantity! +
              data.pickupRevenue!.totalQuantity! +
              data.deliveryRevenue!.totalQuantity! +
              data.webDeliveryRevenue!.totalQuantity! +
              data.webPickupRevenue!.totalQuantity!),
          styles: const PosStyles(
            bold: true,
          ),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...((data.dineInRevenue!.totalPrice! +
                            data.pickupRevenue!.totalPrice! +
                            data.deliveryRevenue!.totalPrice! +
                            data.webDeliveryRevenue!.totalPrice! +
                            data.webPickupRevenue!.totalPrice!)
                        .toDouble()
                        .toStringAsFixed(2) +
                    "  ")
                .codeUnits,
          ]),
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.emptyLines(1);
    bytes += ticket.text(
      "Payment Details",
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += ticket.hr(ch: "-", len: 58);
    bytes += ticket.row(
      [
        PosColumn(
          text: "Cash",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.cashRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.cashRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.row(
      [
        PosColumn(
          text: "Card",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.cardRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.cardRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.row(
      [
        PosColumn(
          text: "Not Paid",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.notPaidRevenue!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.notPaidRevenue!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.emptyLines(1);
    bytes += ticket.text(
      "Total Discounts",
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += ticket.hr(ch: "-", len: 58);
    bytes += ticket.row(
      [
        PosColumn(
          text: "Online",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.onlineDiscount!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.onlineDiscount!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.row(
      [
        PosColumn(
          text: "InStore",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.inStoreDiscount!.totalQuantity),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...data.inStoreDiscount!.totalPrice!
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );
    bytes += ticket.emptyLines(1);
    bytes += ticket.row(
      [
        PosColumn(
          text: "Total",
          width: 5,
        ),
        PosColumn(
          text: getQuantity(data.inStoreDiscount!.totalQuantity! +
              data.onlineDiscount!.totalQuantity!),
          width: 3,
        ),
        PosColumn(
          textEncoded: Uint8List.fromList([
            ...utf8.encode(symbol),
            ...(data.inStoreDiscount!.totalPrice! +
                    data.onlineDiscount!.totalPrice!)
                .toDouble()
                .toStringAsFixed(2)
                .codeUnits,
            ..."  ".codeUnits,
          ]),
          styles: const PosStyles(
            align: PosAlign.right,
          ),
          width: 4,
        ),
      ],
    );

    bytes += ticket.emptyLines(1);
    bytes += ticket.rawBytes([29, 40, 69, 3, 0, 6, 10, 12]);

    bytes += ticket.text(
      "powered by FASTFOOD",
      styles: const PosStyles(
        align: PosAlign.center,
      ),
    );
    bytes += ticket.rawBytes([29, 40, 69, 3, 0, 6, 10, 15]);

    bytes += ticket.emptyLines(2);
    bytes += ticket.cut();
    return bytes;
  }

  String getQuantity(int? totalQuantity) {
    return "(" + totalQuantity.toString() + ")";
  }

  ///New Receipt

  Future<List<int>> agetPrintingPosBytes(
    PData pdata, {
    bool reprint = false,
  }) async {
    List<int> bytes = [];
    final ticket = Generator(
      PaperSizeWidth.mm80,
      56,
      await CapabilityProfile.load(),
    );
    bytes += ticket.reset();
    bytes += ticket.resetPrinter();
    bytes += ticket.setFontSize(16);
    bytes += ticket.setVectorFont();
    if (pdata.selectPaymentOption == "Cash" &&
        reprint == false &&
        pdata.orderType != 0 &&
        pdata.orderType != 3) {
      bytes += ticket.drawer();
    }
    final shouldPrintLogo = LocalStorage.userDataBox.read('printLogo') ?? false;
    final storeData = LocalStorage().getUserData()!.userData!.storeData;
    if (shouldPrintLogo) {
      final imageUrl = storeData!.storeImage!.baseUrl! +
          storeData.storeImage!.attachmentUrl!;
      if (LocalStorage.userDataBox.hasData('logo')) {
        final storeImageBytes = LocalStorage.userDataBox.read('logo');
        List<int> imageBytes = [];
        jsonDecode(storeImageBytes).forEach((element) {
          imageBytes.add(element);
        });
        final image = decodeImage(
          Uint8List.fromList(imageBytes),
        );
        //Resize image to 150px width and 150px height
        final resizedImage = copyResize(image!, width: 150, height: 150);
        bytes += ticket.image(resizedImage);
      } else {
        final storeImageBytes =
            (await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl))
                .buffer
                .asUint8List();
        LocalStorage.userDataBox.write(
          'logo',
          storeImageBytes.toList().toString(),
        );
        final image = decodeImage(storeImageBytes);
        //Resize image to 150px width and 150px height
        final resizedImage = copyResize(image!, width: 150, height: 150);
        bytes += ticket.image(resizedImage);
      }
    }
    bytes += ticket.emptyLines(1);
    if (pdata.preOrderStatus != 1) {
      bytes += ticket.text(
        (pdata.orderCategory == 3
                ? "Dine In"
                : pdata.orderCategory == 1
                    ? "Collection"
                    : "Delivery")
            .toUpperCase(),
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    } else {
      bytes += ticket.row([
        PosColumn(
          text: (pdata.orderCategory == 3
                  ? "Dine In"
                  : pdata.orderCategory == 1
                      ? "Collection"
                      : "Delivery")
              .toUpperCase(),
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
          width: 7,
        ),
        PosColumn(
          text: "   Pre Order  ".toUpperCase(),
          styles: const PosStyles(
            reverse: true,
          ),
          width: 5,
        ),
      ]);
      bytes += ticket.row([
        PosColumn(
          text: ''.toUpperCase(),
          width: 7,
        ),
        PosColumn(
          text: DateFormat('dd/MM/yy HH:mm').format(
              DateFormat('EEEE dd-MM-yyy hh:mm a').parse(pdata.selectedDate)),
          styles: const PosStyles(
            reverse: true,
          ),
          width: 5,
        ),
      ]);
    }
    bytes += ticket.setFontSize(15);
    if (pdata.customerName != null && pdata.customerName != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.customerName.toString(),
        styles: const PosStyles(
          bold: true,
        ),
      );
    }
    if (pdata.deliveryAddress != null && pdata.deliveryAddress != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.deliveryAddress.toString(),
        styles: const PosStyles(
          bold: true,
        ),
      );
      bytes += ticket.setFontSize(15);
    }
    if (pdata.zipCode != null && pdata.zipCode != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.zipCode.toString().toUpperCase(),
        styles: const PosStyles(
          bold: true,
        ),
      );
      bytes += ticket.setFontSize(15);
    }
    if (pdata.customerMobileNo != null && pdata.customerMobileNo != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.customerMobileNo.toString(),
        styles: const PosStyles(
          bold: true,
        ),
      );
    }
    // bytes += ticket.emptyLines(1);
    bytes += ticket.setFontSize(15);
    bytes += ticket.hr(
      len: 37,
    );
    int itemsSize = (await LocalStorage.userDataBox.read("itemsSize")) ?? 15;
    bytes += ticket.setFontSize(itemsSize);
    for (final element in pdata.items) {
      bytes += ticket.enableBold();
      final name = element.itemQuantity.toString() +
          "  " +
          (element.variationName != null
              ? "${element.variationName} ${element.itemName}"
              : element.itemName);
      if (name.length > 25) {
        bytes += ticket.textEncoded(
          Uint8List.fromList([
            ...utf8.encode(
              getRow(
                name.substring(0, 25),
                symbol + double.parse(element.originalPrice).toStringAsFixed(2),
              ),
            ),
          ]),
        );
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              "   " + name.substring(25),
              "",
            ),
          ),
        ]));
      } else {
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              name,
              symbol + double.parse(element.originalPrice).toStringAsFixed(2),
            ),
          ),
        ]));
      }
      if (element.selectedSteps != null) {
        bytes += ticket.disableBold();
        for (final steps in element.selectedSteps!) {
          final name = "    -" + steps.stepName;
          final price = double.parse(steps.price) > 0
              ? symbol + double.parse(steps.price).toStringAsFixed(2)
              : "";
          if (name.length > 25) {
            bytes += ticket.textEncoded(
              Uint8List.fromList([
                ...utf8.encode(
                  getRow(
                    name.substring(0, 25),
                    price,
                  ),
                ),
              ]),
            );
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  "   " + name.substring(25),
                  "",
                ),
              ),
            ]));
          } else {
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  name,
                  price,
                ),
              ),
            ]));
          }
        }
      }
      if (element.selectedAddOns != null) {
        bytes += ticket.enableBold();
        for (final addons in element.selectedAddOns!) {
          final name = "1  " + addons.addOnName;
          final price = double.parse(addons.price) > 0
              ? symbol + double.parse(addons.price).toStringAsFixed(2)
              : "";
          if (name.length > 25) {
            bytes += ticket.textEncoded(
              Uint8List.fromList([
                ...utf8.encode(
                  getRow(
                    name.substring(0, 25),
                    price,
                  ),
                ),
              ]),
            );
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  "   " + name.substring(25),
                  "",
                ),
              ),
            ]));
          } else {
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  name,
                  price,
                ),
              ),
            ]));
          }
        }
      }
      bytes += ticket.hr(
        len: 37,
      );
    }
    for (final element in pdata.addamounts) {
      bytes += ticket.enableBold();
      final name =
          element['quantity'].toString() + "  " + element['title'].toString();
      final price = double.parse(element['amount'].toString()) > 0
          ? symbol +
              double.parse(element['amount'].toString()).toStringAsFixed(2)
          : "";
      if (name.length > 25) {
        bytes += ticket.textEncoded(
          Uint8List.fromList([
            ...utf8.encode(
              getRow(
                name.substring(0, 25),
                price,
              ),
            ),
          ]),
        );
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              "   " + name.substring(25),
              "",
            ),
          ),
        ]));
      } else {
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              name,
              price,
            ),
          ),
        ]));
      }
      bytes += ticket.hr(
        len: 37,
      );
    }
    bytes += ticket.enableBold();
    bytes += ticket.textEncoded(Uint8List.fromList([
      ...utf8.encode(
        getRow(
          "Sub Total",
          symbol + double.parse(getTotal(pdata).toString()).toStringAsFixed(2),
        ),
      ),
    ]));

    bytes += ticket.disableBold();
    if (pdata.discount != null &&
        pdata.discount!.isNotEmpty &&
        pdata.discount != "0" &&
        double.parse(pdata.discount!) > 0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Discount",
            symbol + double.parse(pdata.discount!).toStringAsFixed(2),
          ),
        ),
      ]));
    }
    if (pdata.deliveryCharges != null &&
        pdata.deliveryCharges!.isNotEmpty &&
        pdata.deliveryCharges != "0" &&
        double.parse(pdata.deliveryCharges!) > 0 &&
        pdata.orderCategory == 2) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Delivery Charge",
            symbol + double.parse(pdata.deliveryCharges!).toStringAsFixed(2),
          ),
        ),
      ]));
    }
    if (pdata.serviceCharge != null &&
        pdata.serviceCharge!.isNotEmpty &&
        pdata.serviceCharge != "0" &&
        double.parse(pdata.serviceCharge!) > 0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Service Charge",
            symbol + double.parse(pdata.serviceCharge!).toStringAsFixed(2),
          ),
        ),
      ]));
    }
    if (pdata.minimumOrderFees != 0.0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Small Order Fee",
            symbol +
                double.parse(pdata.minimumOrderFees.toString())
                    .toStringAsFixed(2),
          ),
        ),
      ]));
    }
    if (pdata.tip != null &&
        pdata.tip!.isNotEmpty &&
        double.parse(pdata.tip!) > 0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Tip",
            symbol + double.parse(pdata.tip!).toStringAsFixed(2),
          ),
        ),
      ]));
    }
    bytes += ticket.emptyLines(1);
    bytes += ticket.enableBold();

    bytes += ticket.textEncoded(Uint8List.fromList([
      ...utf8.encode(
        getRow(
          "TOTAL",
          symbol +
              (pdata.totalPrice + double.parse(pdata.tip ?? "0.0"))
                  .toStringAsFixed(2),
        ),
      ),
    ]));
    bytes += ticket.disableBold();
    bytes += ticket.hr(
      len: 37,
    );
    bytes += ticket.enableBold();
    bytes += ticket.text(
      pdata.orderType == 3
          ? "CASH"
          : pdata.orderType == 0
              ? "PAID"
              : pdata.orderType == 2
                  ? "NOT PAID"
                  : pdata.selectPaymentOption.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        width: PosTextSize.size2,
        height: PosTextSize.size2,
      ),
    );
    bytes += ticket.emptyLines(1);
    bytes += ticket.disableBold();
    bytes += ticket.text(
      "Placed:" +
          DateFormat('dd/MM/yy hh:mm a').format(pdata.orderTime == null
              ? DateTime.now()
              : TZDateTime.from(DateTime.parse(pdata.orderTime!),
                  getLocation('Europe/London'))),
    );
    bytes += ticket.emptyLines(1);
    if (pdata.orderCategory == 1 && pdata.orderType != 1) {
      bytes += ticket.text(
        "Pickup Time:" +
            DateFormat('dd/MM/yy hh:mm a').format(
                DateFormat('EEEE dd-MM-yyy hh:mm a').parse(pdata.selectedDate)),
      );
    }
    if (pdata.orderCategory == 2 &&
        (pdata.orderType != 1) &&
        pdata.preOrderStatus == 1) {
      bytes += ticket.text(
        "Deliver By: " +
            DateFormat('dd/MM/yy hh:mm a').format(
                DateFormat('EEEE dd-MM-yyy hh:mm a').parse(pdata.selectedDate)),
      );
    }

    bytes += ticket.text(
      "OrderId: " +
          getOrderId(
            pdata.orderId.toString(),
          ),
      styles: const PosStyles(
        bold: true,
      ),
    );
    bytes += ticket.text(
      getRow(
          "Order Through", pdata.orderType == 1 ? "Offline POS" : "Online Web"),
      styles: const PosStyles(
        bold: true,
      ),
    );
    bytes += ticket.hr(
      len: 37,
    );

    final storeName = storeData!.storeName ?? "";
    final storeAddress = storeData.address ?? '';
    final storeNumber = storeData.phoneNumber ?? "";
    bytes += ticket.text(storeName);
    if (storeAddress.isNotEmpty) {
      bytes += ticket.text(storeAddress);
    }
    if (storeNumber.isNotEmpty) {
      bytes += ticket.text(storeNumber);
    }
    if (pdata.notes != null && pdata.notes!.isNotEmpty) {
      bytes += ticket.textEncoded(
        Uint8List.fromList([
          ...utf8.encode("Note: " + pdata.notes!),
        ]),
      );
    }
    bytes += ticket.hr(
      len: 37,
    );

    bytes += ticket.text(
      LocalStorage().getBillnumber(pdata.orderId, reprint).toString(),
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    LocalStorage.shared.setPrinted(pdata.orderId);
    bytes += ticket.emptyLines(2);
    bytes += ticket.feed(1);
    bytes += ticket.cut();
    final printToken = LocalStorage.shared.printToken();
    if (printToken && !reprint && pdata.orderType == 1) {
      bytes += ticket.emptyLines(2);
      bytes += ticket.setFontSize(25);
      bytes += ticket.enableBold();
      bytes += ticket.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += ticket.emptyLines(1);
      bytes += ticket.text(
        LocalStorage().getBillnumber(pdata.orderId, true).toString(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += ticket.emptyLines(2);
      bytes += ticket.cut();
    }
    bytes += ticket.beep(n: 2, duration: PosBeepDuration.beep100ms);
    return bytes;
  }

  Future<List<int>> getPrintingPosBytes(
    PData pdata, {
    bool reprint = false,
  }) async {
    List<int> bytes = [];
    final ticket = Generator(
      PaperSizeWidth.mm80,
      62,
      await CapabilityProfile.load(),
    );
    bytes += ticket.reset();
    bytes += ticket.resetPrinter();
    bytes += ticket.setFontSize(17);
    bytes += ticket.setArialFont();
    if (pdata.selectPaymentOption == "Cash" &&
        reprint == false &&
        pdata.orderType != 0 &&
        pdata.orderType != 3) {
      bytes += ticket.drawer();
    }
    final shouldPrintLogo = LocalStorage.userDataBox.read('printLogo') ?? false;
    final storeData = LocalStorage().getUserData()!.userData!.storeData;
    if (shouldPrintLogo) {
      final imageUrl = storeData!.storeImage!.baseUrl! +
          storeData.storeImage!.attachmentUrl!;
      if (LocalStorage.userDataBox.hasData('logo')) {
        final storeImageBytes = LocalStorage.userDataBox.read('logo');
        List<int> imageBytes = [];
        jsonDecode(storeImageBytes).forEach((element) {
          imageBytes.add(element);
        });
        final image = decodeImage(
          Uint8List.fromList(imageBytes),
        );
        //Resize image to 150px width and 150px height
        final resizedImage = copyResize(image!, width: 150, height: 150);
        bytes += ticket.image(resizedImage);
      } else {
        final storeImageBytes =
            (await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl))
                .buffer
                .asUint8List();
        LocalStorage.userDataBox.write(
          'logo',
          storeImageBytes.toList().toString(),
        );
        final image = decodeImage(storeImageBytes);
        //Resize image to 150px width and 150px height
        final resizedImage = copyResize(image!, width: 150, height: 150);
        bytes += ticket.image(resizedImage);
      }
    }
    bytes += ticket.emptyLines(1);
    if (pdata.preOrderStatus != 1) {
      bytes += ticket.text(
        (pdata.orderCategory == 3
                ? "Dine In"
                : pdata.orderCategory == 1
                    ? "Collection"
                    : "Delivery")
            .toUpperCase(),
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    } else {
      bytes += ticket.row([
        PosColumn(
          text: (pdata.orderCategory == 3
                  ? "Dine In"
                  : pdata.orderCategory == 1
                      ? "Collection"
                      : "Delivery")
              .toUpperCase(),
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
          width: 7,
        ),
        PosColumn(
          text: "   Pre Order  ".toUpperCase(),
          styles: const PosStyles(
            reverse: true,
          ),
          width: 5,
        ),
      ]);
      bytes += ticket.row([
        PosColumn(
          text: ''.toUpperCase(),
          width: 7,
        ),
        PosColumn(
          text: DateFormat('dd/MM/yy HH:mm').format(
              DateFormat('EEEE dd-MM-yyy hh:mm a').parse(pdata.selectedDate)),
          styles: const PosStyles(
            reverse: true,
          ),
          width: 5,
        ),
      ]);
    }
    bytes += ticket.setFontSize(15);
    if (pdata.customerName != null && pdata.customerName != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.customerName.toString(),
        styles: const PosStyles(
          bold: true,
        ),
      );
    }
    if (pdata.deliveryAddress != null && pdata.deliveryAddress != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.deliveryAddress.toString(),
        styles: const PosStyles(
          bold: true,
        ),
      );
      bytes += ticket.setFontSize(15);
    }
    if (pdata.zipCode != null && pdata.zipCode!.isNotEmpty) {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.zipCode.toString().toUpperCase(),
        styles: const PosStyles(
          bold: true,
        ),
      );
      bytes += ticket.setFontSize(15);
    }
    if (pdata.customerMobileNo != null && pdata.customerMobileNo != "") {
      final addressSize =
          (await LocalStorage.userDataBox.read("addressSize")) ?? 22;
      bytes += ticket.setFontSize(addressSize);
      bytes += ticket.text(
        pdata.customerMobileNo.toString(),
        styles: const PosStyles(
          bold: true,
        ),
      );
    }
    bytes += ticket.setFontSize(15);
    bytes += ticket.hr(len: 58);
    int itemsSize = (await LocalStorage.userDataBox.read("itemsSize")) ?? 15;
    bytes += ticket.setFontSize(itemsSize);
    for (final element in pdata.items) {
      bytes += ticket.enableBold();
      final name = element.itemQuantity.toString() +
          "  " +
          (element.variationName != null
              ? "${element.variationName} ${element.itemName}"
              : element.itemName);
      if (name.length > 25) {
        bytes += ticket.textEncoded(
          Uint8List.fromList([
            ...utf8.encode(
              getRow(
                name.substring(0, 25),
                symbol + double.parse(element.price).toStringAsFixed(2),
                lines: 56,
              ),
            ),
          ]),
        );
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              "   " + name.substring(25),
              "",
              lines: 56,
            ),
          ),
        ]));
      } else {
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              name,
              symbol + double.parse(element.price).toStringAsFixed(2),
              lines: 56,
            ),
          ),
        ]));
      }
      if (element.selectedSteps != null) {
        bytes += ticket.disableBold();
        for (final steps in element.selectedSteps!) {
          final name = "    -" + steps.stepName;
          final price = double.parse(steps.price) > 0
              ? symbol + double.parse(steps.price).toStringAsFixed(2)
              : "";
          if (name.length > 25) {
            bytes += ticket.textEncoded(
              Uint8List.fromList([
                ...utf8.encode(
                  getRow(
                    name.substring(0, 25),
                    price,
                    lines: 56,
                  ),
                ),
              ]),
            );
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  "   " + name.substring(25),
                  "",
                  lines: 56,
                ),
              ),
            ]));
          } else {
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  name,
                  price,
                  lines: 56,
                ),
              ),
            ]));
          }
        }
      }
      if (element.selectedAddOns != null) {
        bytes += ticket.enableBold();
        for (final addons in element.selectedAddOns!) {
          final name = "1  " + addons.addOnName;
          final price = double.parse(addons.price) > 0
              ? symbol + double.parse(addons.price).toStringAsFixed(2)
              : "";
          if (name.length > 25) {
            bytes += ticket.textEncoded(
              Uint8List.fromList([
                ...utf8.encode(
                  getRow(
                    name.substring(0, 25),
                    price,
                    lines: 56,
                  ),
                ),
              ]),
            );
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  "   " + name.substring(25),
                  "",
                  lines: 56,
                ),
              ),
            ]));
          } else {
            bytes += ticket.textEncoded(Uint8List.fromList([
              ...utf8.encode(
                getRow(
                  name,
                  price,
                  lines: 56,
                ),
              ),
            ]));
          }
        }
      }
      bytes += ticket.hr(len: 58);
    }
    for (final element in pdata.addamounts) {
      bytes += ticket.enableBold();
      final name =
          element['quantity'].toString() + "  " + element['title'].toString();
      final price = double.parse(element['amount'].toString()) > 0
          ? symbol +
              double.parse(element['amount'].toString()).toStringAsFixed(2)
          : "";
      if (name.length > 25) {
        bytes += ticket.textEncoded(
          Uint8List.fromList([
            ...utf8.encode(
              getRow(
                name.substring(0, 25),
                price,
                lines: 56,
              ),
            ),
          ]),
        );
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              "   " + name.substring(25),
              "",
              lines: 56,
            ),
          ),
        ]));
      } else {
        bytes += ticket.textEncoded(Uint8List.fromList([
          ...utf8.encode(
            getRow(
              name,
              price,
              lines: 56,
            ),
          ),
        ]));
      }
      bytes += ticket.hr(len: 58);
    }
    bytes += ticket.enableBold();
    bytes += ticket.textEncoded(Uint8List.fromList([
      ...utf8.encode(
        getRow(
          "Sub Total",
          symbol + double.parse(getTotal(pdata).toString()).toStringAsFixed(2),
          lines: 56,
        ),
      ),
    ]));

    bytes += ticket.disableBold();
    if (pdata.discount != null &&
        pdata.discount!.isNotEmpty &&
        pdata.discount != "0" &&
        double.parse(pdata.discount!) > 0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Discount",
            symbol + double.parse(pdata.discount!).toStringAsFixed(2),
            lines: 56,
          ),
        ),
      ]));
    }
    if (pdata.deliveryCharges != null &&
        pdata.deliveryCharges!.isNotEmpty &&
        pdata.deliveryCharges != "0" &&
        double.parse(pdata.deliveryCharges!) > 0 &&
        pdata.orderCategory == 2) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Delivery Charge",
            symbol + double.parse(pdata.deliveryCharges!).toStringAsFixed(2),
            lines: 56,
          ),
        ),
      ]));
    }
    if (pdata.serviceCharge != null &&
        pdata.serviceCharge!.isNotEmpty &&
        pdata.serviceCharge != "0" &&
        double.parse(pdata.serviceCharge!) > 0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Service Charge",
            symbol + double.parse(pdata.serviceCharge!).toStringAsFixed(2),
            lines: 56,
          ),
        ),
      ]));
    }
    if (pdata.minimumOrderFees != 0.0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Small Order Fee",
            symbol +
                double.parse(pdata.minimumOrderFees.toString())
                    .toStringAsFixed(2),
            lines: 56,
          ),
        ),
      ]));
    }
    if (pdata.tip != null &&
        pdata.tip!.isNotEmpty &&
        double.parse(pdata.tip!) > 0) {
      bytes += ticket.textEncoded(Uint8List.fromList([
        ...utf8.encode(
          getRow(
            "Tip",
            symbol + double.parse(pdata.tip!).toStringAsFixed(2),
            lines: 56,
          ),
        ),
      ]));
    }
    bytes += ticket.emptyLines(1);
    bytes += ticket.enableBold();

    bytes += ticket.textEncoded(Uint8List.fromList([
      ...utf8.encode(
        getRow(
          "TOTAL",
          symbol +
              (pdata.totalPrice + double.parse(pdata.tip ?? "0.0"))
                  .toStringAsFixed(2),
          lines: 56,
        ),
      ),
    ]));
    bytes += ticket.disableBold();
    bytes += ticket.hr(len: 58);
    bytes += ticket.enableBold();
    bytes += ticket.text(
      pdata.orderType == 3
          ? "CASH"
          : pdata.orderType == 0
              ? "PAID"
              : pdata.orderType == 2
                  ? "NOT PAID"
                  : pdata.selectPaymentOption.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        width: PosTextSize.size2,
        height: PosTextSize.size2,
      ),
    );
    bytes += ticket.emptyLines(1);
    bytes += ticket.disableBold();
    bytes += ticket.text(
      "Placed:" +
          DateFormat('dd/MM/yy hh:mm a').format(pdata.orderTime == null
              ? DateTime.now()
              : TZDateTime.from(DateTime.parse(pdata.orderTime!),
                  getLocation('Europe/London'))),
    );
    bytes += ticket.emptyLines(1);
    if (pdata.orderCategory == 1 && pdata.orderType != 1) {
      bytes += ticket.text(
        "Pickup Time:" +
            DateFormat('dd/MM/yy hh:mm a').format(
                DateFormat('EEEE dd-MM-yyy hh:mm a').parse(pdata.selectedDate)),
      );
    }
    if (pdata.orderCategory == 2 &&
        (pdata.orderType != 1) &&
        pdata.preOrderStatus == 1) {
      bytes += ticket.text(
        "Deliver By: " +
            DateFormat('dd/MM/yy hh:mm a').format(
                DateFormat('EEEE dd-MM-yyy hh:mm a').parse(pdata.selectedDate)),
      );
    }

    bytes += ticket.text(
      "OrderId: " +
          getOrderId(
            pdata.orderId.toString(),
          ),
      styles: const PosStyles(
        bold: true,
      ),
    );
    bytes += ticket.text(
      getRow(
        "Order Through",
        pdata.orderType == 1 ? "Offline POS" : "Online Web",
        lines: 56,
      ),
      styles: const PosStyles(
        bold: true,
      ),
    );
    bytes += ticket.hr(len: 58);

    final storeName = storeData!.storeName ?? "";
    final storeAddress = storeData.address ?? '';
    final storeNumber = storeData.phoneNumber ?? "";
    bytes += ticket.text(storeName);
    if (storeAddress.isNotEmpty) {
      bytes += ticket.text(storeAddress);
    }
    if (storeNumber.isNotEmpty) {
      bytes += ticket.text(storeNumber);
    }
    if (pdata.notes != null && pdata.notes!.isNotEmpty) {
      bytes += ticket.textEncoded(
        Uint8List.fromList([
          ...utf8.encode("Note: " + pdata.notes!),
        ]),
      );
    }
    bytes += ticket.hr(len: 58);

    bytes += ticket.text(
      LocalStorage().getBillnumber(pdata.orderId, reprint).toString(),
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    LocalStorage.shared.setPrinted(pdata.orderId);
    bytes += ticket.emptyLines(2);
    bytes += ticket.feed(1);
    bytes += ticket.cut();
    final printToken = LocalStorage.shared.printToken();
    if (printToken && !reprint) {
      bytes += ticket.emptyLines(2);
      bytes += ticket.setFontSize(25);
      bytes += ticket.enableBold();
      bytes += ticket.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );
      bytes += ticket.emptyLines(1);
      bytes += ticket.text(
        LocalStorage().getBillnumber(pdata.orderId, true).toString(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += ticket.emptyLines(2);
      bytes += ticket.cut();
    }
    bytes += ticket.beep(n: 2, duration: PosBeepDuration.beep100ms);
    return bytes;
  }

  ///New Printing
  Future<List<int>> printReceipt(
    PData pdata, {
    bool reprint = false,
  }) async {
    List<int> bytes = [];
    final ticket = Generator(
      PaperSizeWidth.mm80,
      PaperSizeMaxPerLine.mm80,
      await CapabilityProfile.load(),
    );
    bytes += ticket.reset();
    final textstyle = GoogleFonts.inter(
      color: Colors.black,
    );
    final shouldPrintLogo = LocalStorage.userDataBox.read('printLogo') ?? false;
    final storeData = LocalStorage().getUserData()!.userData!.storeData;
    // if (shouldPrintLogo) {
    //   final imageUrl = storeData!.storeImage!.baseUrl! +
    //       storeData.storeImage!.attachmentUrl!;
    // }

    return bytes;
  }

  Container space({double height = 0, double width = 0}) {
    return Container(
      height: height,
      width: width,
      color: Colors.white,
    );
  }

  Widget dottedLine() {
    return Container(
      width: 380,
      height: 2,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) {
          return Container(
            width: 5,
            height: 1,
            color: Colors.white,
          );
        },
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 300,
        itemBuilder: (context, index) {
          return Container(
            height: 1,
            width: 7,
            color: Colors.black,
          );
        },
      ),
    );
  }

  final style = GoogleFonts.openSans(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );
}

extension PrinterExtension on Generator {
  List<int> resetPrinter() {
    return rawBytes([29, 40, 69, 3, 0, 6, 3, 255]);
  }

  List<int> setFontSize(int? size) {
    return rawBytes([29, 40, 69, 3, 0, 6, 10, size ?? 15]);
  }

  List<int> setArialFont() {
    return rawBytes([29, 40, 69, 3, 0, 6, 20, 128]);
  }

  List<int> setVectorFont() {
    return rawBytes([29, 40, 69, 3, 0, 6, 20, 128]);
  }

  List<int> enableBold() {
    return rawBytes([27, 69, 1]);
  }

  List<int> disableBold() {
    return rawBytes([27, 69, 0]);
  }

  List<int> horizontalLine() {
    return rawBytes([27, 45, 1]);
  }
}
