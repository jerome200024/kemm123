import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTimeRange? selectedDateRange;
  List<Map<String, dynamic>> actions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    DateTime today = DateTime.now();
    selectedDateRange ??= DateTimeRange(start: today, end: today);
    _fetchActions(); // Fetch initial data
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
      initialDateRange: selectedDateRange,
    );

    if (pickedRange != null) {
      setState(() {
        selectedDateRange = pickedRange;
      });
    }
  }

  Future<void> _fetchActions() async {
    if (selectedDateRange == null) return;
    setState(() => isLoading = true);

    final start = DateTime(
      selectedDateRange!.start.year,
      selectedDateRange!.start.month,
      selectedDateRange!.start.day,
    );
    final end = DateTime(
      selectedDateRange!.end.year,
      selectedDateRange!.end.month,
      selectedDateRange!.end.day,
      23, 59, 59, 999,
    );

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        actions = [];
        isLoading = false;
      });
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('actions')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      actions = query.docs.map((doc) => doc.data()).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTimeRange safeRange = selectedDateRange ??
        DateTimeRange(start: DateTime.now(), end: DateTime.now());

    String startDate = DateFormat('MMM dd, yyyy').format(safeRange.start);
    String endDate = DateFormat('MMM dd, yyyy').format(safeRange.end);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ✅ Green Header with Title and Logo
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade400,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ✅ Title
                    Text(
                      "History",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    // ✅ Logo
                    Image.asset(
                      'assets/growater_logo.png',
                      scale: 10, // Adjust size as needed
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // ✅ Filter Row with Date Picker & Apply Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Filter:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // Date Picker Button
                ElevatedButton(
                  onPressed: _pickDateRange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.black),
                    ),
                  ),
                  child: Text(
                    "$startDate - $endDate",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),

                // Apply Button
                ElevatedButton(
                  onPressed: _fetchActions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade100,
                    padding: EdgeInsets.symmetric(horizontal:15, vertical: 10),
                  ),
                  child: Text(
                    "Apply",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // ✅ Event List Placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Event List",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : actions.isEmpty
                    ? const Center(
                        child: Text(
                          "No events available.",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : SingleChildScrollView(
                        // Only vertical scroll!
                        child: DataTable(
                          columnSpacing: 20, // Adjust as needed
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Time',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Details',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: actions.map((action) {
                            final timestamp = (action['timestamp'] as Timestamp).toDate();
                            final dateStr = DateFormat('yyyy-MM-dd').format(timestamp);
                            final timeStr = DateFormat('h:mm a').format(timestamp);
                            final description = action['description'] ?? '';
                            return DataRow(
                              cells: [
                                DataCell(Text(dateStr)),
                                DataCell(Text(timeStr)),
                                DataCell(
                                  SizedBox(
                                    width: 180, // Increased width from 150 to 180
                                    child: Text(
                                      description,
                                      style: const TextStyle(fontSize: 14),
                                      softWrap: true,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
