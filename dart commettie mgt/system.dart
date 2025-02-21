import 'dart:io';
import 'dart:convert';
import 'dart:math';

// Base directory for all funds
const String baseDir = 'funds';

/// Represents the basic details of a fund.
class Fund {
  String fundName;
  double contributionAmount;
  String durationType; // "Weekly" or "Monthly"
  int durationCount;   // For record (e.g., 5 weeks or 5 months)
  int totalRounds;     // Equals number of members

  Fund({
    required this.fundName,
    required this.contributionAmount,
    required this.durationType,
    required this.durationCount,
    required this.totalRounds,
  });

  Map<String, dynamic> toJson() => {
        'fundName': fundName,
        'contributionAmount': contributionAmount,
        'durationType': durationType,
        'durationCount': durationCount,
        'totalRounds': totalRounds,
      };

  static Fund fromJson(Map<String, dynamic> json) {
    return Fund(
      fundName: json['fundName'],
      contributionAmount: json['contributionAmount'],
      durationType: json['durationType'],
      durationCount: json['durationCount'],
      totalRounds: json['totalRounds'],
    );
  }
}

/// Represents a member in the fund.
class Member {
  int userID;
  String name;
  double balance;

  Member(this.userID, this.name, {this.balance = 0.0});

  Map<String, dynamic> toJson() => {
        'userID': userID,
        'name': name,
        'balance': balance,
      };

  static Member fromJson(Map<String, dynamic> json) {
    return Member(json['userID'], json['name'], balance: json['balance']);
  }
}

/// Represents a transaction (either a deposit or a payout).
class Transaction {
  int transactionID;
  int userID;
  double amount;
  String type; // "Deposit" or "Payout"
  int round;   // Round number in which the transaction occurred

  Transaction(this.transactionID, this.userID, this.amount, this.type, this.round);

  Map<String, dynamic> toJson() => {
        'transactionID': transactionID,
        'userID': userID,
        'amount': amount,
        'type': type,
        'round': round,
      };

  static Transaction fromJson(Map<String, dynamic> json) {
    return Transaction(
      json['transactionID'],
      json['userID'],
      json['amount'],
      json['type'],
      json['round'],
    );
  }
}

/// Maintains the current state of the fund:
/// - currentRound: current round (starting at 0)
/// - currentRoundContributions: list of member IDs who have contributed in the current round
/// - winners: list of member IDs who have already received a payout
class FundState {
  int currentRound;
  List<int> currentRoundContributions;
  List<int> winners;

  FundState({
    this.currentRound = 0,
    List<int>? currentRoundContributions,
    List<int>? winners,
  })  : currentRoundContributions = currentRoundContributions ?? [],
        winners = winners ?? [];

  Map<String, dynamic> toJson() => {
        'currentRound': currentRound,
        'currentRoundContributions': currentRoundContributions,
        'winners': winners,
      };

  static FundState fromJson(Map<String, dynamic> json) {
    return FundState(
      currentRound: json['currentRound'],
      currentRoundContributions: List<int>.from(json['currentRoundContributions']),
      winners: List<int>.from(json['winners']),
    );
  }
}

/// Manages the overall fund operations including file handling.
class FundManager {
  late Fund fund;
  List<Member> members = [];
  List<Transaction> transactions = [];
  late FundState state;
  final Random _random = Random();

  // Folder path for the currently loaded fund.
  late String folderPath;

  // Helper getters for file paths
  String get fundFile => '$folderPath/fund.json';
  String get membersFile => '$folderPath/members.json';
  String get transactionsFile => '$folderPath/transactions.json';
  String get stateFile => '$folderPath/state.json';

  FundManager();

  // Save fund details
  void saveFund() {
    File(fundFile).writeAsStringSync(jsonEncode(fund.toJson()));
  }

  // Load fund details
  bool loadFund() {
    try {
      File f = File(fundFile);
      if (!f.existsSync()) return false;
      Map<String, dynamic> data = jsonDecode(f.readAsStringSync());
      fund = Fund.fromJson(data);
      return true;
    } catch (e) {
      print('Error loading fund: $e');
      return false;
    }
  }

  // Save members
  void saveMembers() {
    File(membersFile).writeAsStringSync(jsonEncode(members.map((m) => m.toJson()).toList()));
  }

  // Load members
  void loadMembers() {
    try {
      File f = File(membersFile);
      if (!f.existsSync()) return;
      List<dynamic> data = jsonDecode(f.readAsStringSync());
      members = data.map((e) => Member.fromJson(e)).toList();
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  // Save transactions
  void saveTransactions() {
    File(transactionsFile).writeAsStringSync(jsonEncode(transactions.map((t) => t.toJson()).toList()));
  }

  // Load transactions
  void loadTransactions() {
    try {
      File f = File(transactionsFile);
      if (!f.existsSync()) return;
      List<dynamic> data = jsonDecode(f.readAsStringSync());
      transactions = data.map((e) => Transaction.fromJson(e)).toList();
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  // Save state
  void saveState() {
    File(stateFile).writeAsStringSync(jsonEncode(state.toJson()));
  }

  // Load state
  void loadState() {
    try {
      File f = File(stateFile);
      if (!f.existsSync()) {
        state = FundState();
        return;
      }
      Map<String, dynamic> data = jsonDecode(f.readAsStringSync());
      state = FundState.fromJson(data);
    } catch (e) {
      print('Error loading state: $e');
      state = FundState();
    }
  }

  // Create a new fund (and clear previous data if any)
  void createNewFund() {
    stdout.write('Enter fund name: ');
    String fundName = stdin.readLineSync()!.trim();

    // Ensure the fund name is unique (folder should not exist)
    String newFundFolder = '$baseDir/$fundName';
    if (Directory(newFundFolder).existsSync()) {
      print('A fund with that name already exists. Please choose a unique fund name.');
      return;
    }

    double contributionAmount = _getDoubleInput('Enter contribution amount: ');
    stdout.write('Enter duration type (1 for Weekly, 2 for Monthly): ');
    String durationChoice = stdin.readLineSync()!;
    String durationType = (durationChoice == '1') ? 'Weekly' : 'Monthly';
    int durationCount = _getIntInput('Enter duration count (e.g., number of weeks/months): ');
    int numMembers = _getIntInput('Enter number of members: ');

    // Create the fund folder
    Directory(newFundFolder).createSync(recursive: true);
    folderPath = newFundFolder;

    // Create fund; totalRounds equals number of members
    fund = Fund(
      fundName: fundName,
      contributionAmount: contributionAmount,
      durationType: durationType,
      durationCount: durationCount,
      totalRounds: numMembers,
    );
    saveFund();

    // Create members
    members = [];
    for (int i = 0; i < numMembers; i++) {
      stdout.write('Enter name for member ${i + 1}: ');
      String name = stdin.readLineSync()!.trim();
      members.add(Member(i + 1, name));
    }
    saveMembers();

    // Clear transactions and state
    transactions = [];
    saveTransactions();
    state = FundState();
    saveState();
    print('Fund "$fundName" created successfully with $numMembers members.');
  }

  // Add a member (only allowed if no contributions have been made)
  void addMember() {
    if (state.currentRound > 0 || state.currentRoundContributions.isNotEmpty) {
      print('Cannot add member after contributions have started.');
      return;
    }
    stdout.write('Enter name for new member: ');
    String name = stdin.readLineSync()!.trim();
    int id = members.length + 1;
    members.add(Member(id, name));
    fund.totalRounds = members.length; // update total rounds
    saveMembers();
    saveFund();
    print('Member "$name" added successfully.');
  }

  // Collect contribution from a member for the current round.
  void collectContribution() {
    // Check if fund rounds have been completed:
    if (state.currentRound >= fund.totalRounds) {
      print('All rounds are completed.');
      _handleFundCompletion();
      return;
    }

    stdout.write('Enter member name for contribution: ');
    String name = stdin.readLineSync()!.trim();
    Member? member = members.firstWhere(
        (m) => m.name.toLowerCase() == name.toLowerCase(),
        orElse: () => Member(0, ''));
    if (member.userID == 0) {
      print('Member not found.');
      return;
    }

    // Check if member already contributed in the current round
    if (state.currentRoundContributions.contains(member.userID)) {
      print('${member.name} has already contributed in the current round.');
      return;
    }

    int transactionID = transactions.length + 1;
    Transaction t = Transaction(transactionID, member.userID, fund.contributionAmount, 'Deposit', state.currentRound + 1);
    transactions.add(t);
    member.balance += fund.contributionAmount;
    state.currentRoundContributions.add(member.userID);
    print('Contribution recorded for ${member.name}.');

    saveTransactions();
    saveMembers();
    saveState();

    // If the round is complete (all members contributed), inform the user.
    if (state.currentRoundContributions.length == members.length) {
      print('Round ${state.currentRound + 1} completed.');
    }
  }

  // Process payout if the current round is complete.
  void payoutMoney() {
    if (state.currentRoundContributions.length != members.length) {
      print('Not all members have contributed for the current round.');
      return;
    }

    // Eligible members: those who have not yet received a payout
    List<Member> eligible = members.where((m) => !state.winners.contains(m.userID)).toList();
    if (eligible.isEmpty) {
      print('All members have already received a payout in this fund.');
      _handleFundCompletion();
      return;
    }

    // Randomly select a winner from eligible members.
    Member winner = eligible[_random.nextInt(eligible.length)];
    double pool = fund.contributionAmount * members.length; // one contribution per member in the round
    int transactionID = transactions.length + 1;
    Transaction t = Transaction(transactionID, winner.userID, pool, 'Payout', state.currentRound + 1);
    transactions.add(t);
    winner.balance -= pool;
    state.winners.add(winner.userID);
    print('Payout of Rs. $pool given to ${winner.name} in round ${state.currentRound + 1}.');

    saveTransactions();
    saveMembers();
    saveState();

    // Prepare for next round:
    state.currentRoundContributions.clear();
    state.currentRound++;
    saveState();

    // If all rounds are completed, handle fund completion.
    if (state.currentRound >= fund.totalRounds) {
      print('All rounds are completed.');
      _handleFundCompletion();
    }
  }

  // When fund rounds are completed, offer options:
  // 1. Restart fund (preserve members and contribution amount; clear transactions/state)
  // 2. Edit and restart fund (reset members and contribution details; fund name remains)
  // 3. End fund (exit while keeping records)
  void _handleFundCompletion() {
    print('\nFund rounds are completed.');
    print('Choose an option:');
    print('1. Restart fund (preserve members and contribution amount)');
    print('2. Edit and restart fund (reset members and contribution details; fund name remains)');
    print('3. End fund (no further actions)');
    stdout.write('Enter choice: ');
    String? choice = stdin.readLineSync();
    switch (choice) {
      case '1':
        _restartFund(preserveMembers: true);
        break;
      case '2':
        _restartFund(preserveMembers: false);
        break;
      case '3':
        print('Fund ended. Records are maintained.');
        exit(0);
      default:
        print('Invalid choice.');
    }
  }

  // Restart the fund.
  // If preserveMembers is true, reset rounds, transactions, and state (keeping members and contribution details).
  // If false, ask for new contribution details and members (fund name remains).
  void _restartFund({required bool preserveMembers}) {
    if (preserveMembers) {
      transactions = [];
      saveTransactions();
      state = FundState();
      saveState();
      print('Fund restarted with existing members and contribution details.');
    } else {
      stdout.write('Enter new contribution amount: ');
      double newContribution = _getDoubleInput('');
      stdout.write('Enter duration type (1 for Weekly, 2 for Monthly): ');
      String durationChoice = stdin.readLineSync()!;
      String newDurationType = (durationChoice == '1') ? 'Weekly' : 'Monthly';
      int newDurationCount = _getIntInput('Enter new duration count (e.g., number of weeks/months): ');
      int numMembers = _getIntInput('Enter number of members: ');
      List<Member> newMembers = [];
      for (int i = 0; i < numMembers; i++) {
        stdout.write('Enter name for member ${i + 1}: ');
        String name = stdin.readLineSync()!.trim();
        newMembers.add(Member(i + 1, name));
      }
      fund.contributionAmount = newContribution;
      fund.durationType = newDurationType;
      fund.durationCount = newDurationCount;
      fund.totalRounds = numMembers;
      saveFund();
      members = newMembers;
      saveMembers();
      transactions = [];
      saveTransactions();
      state = FundState();
      saveState();
      print('Fund restarted with new members and contribution details.');
    }
  }

  // Utility to get integer input with error handling.
  int _getIntInput(String prompt) {
    while (true) {
      if (prompt.isNotEmpty) stdout.write(prompt);
      String? input = stdin.readLineSync();
      try {
        int value = int.parse(input ?? '');
        return value;
      } catch (e) {
        print('Invalid input. Please enter an integer.');
      }
    }
  }

  // Utility to get double input with error handling.
  double _getDoubleInput(String prompt) {
    while (true) {
      if (prompt.isNotEmpty) stdout.write(prompt);
      String? input = stdin.readLineSync();
      try {
        double value = double.parse(input ?? '');
        return value;
      } catch (e) {
        print('Invalid input. Please enter a number.');
      }
    }
  }

  // Display the fund menu repeatedly until exit.
  void fundMenu() {
    while (true) {
      print('\n--- Fund Menu ---');
      print('1. Add Member (only before any contributions)');
      print('2. Collect Contribution');
      print('3. Payout Money');
      print('4. Exit');
      stdout.write('Enter choice: ');
      String? choice = stdin.readLineSync();
      switch (choice) {
        case '1':
          addMember();
          break;
        case '2':
          collectContribution();
          break;
        case '3':
          payoutMoney();
          break;
        case '4':
          print('Exiting.');
          exit(0);
        default:
          print('Invalid choice.');
      }
    }
  }
}

/// Lists all existing funds (i.e. directories in the baseDir)
void viewExistingFunds() {
  Directory dir = Directory(baseDir);
  if (!dir.existsSync()) {
    print('No funds found.');
    return;
  }
  List<FileSystemEntity> items = dir.listSync();
  if (items.isEmpty) {
    print('No funds found.');
    return;
  }
  print('Existing funds:');
  for (var item in items) {
    if (item is Directory) {
      print('- ${item.uri.pathSegments.last}');
    }
  }
}

/// Prompts the user to choose a fund from the list and returns its folder path.
String? chooseFundToLoad() {
  Directory dir = Directory(baseDir);
  if (!dir.existsSync()) {
    print('No funds available.');
    return null;
  }
  List<FileSystemEntity> items = dir.listSync();
  List<String> fundNames = [];
  for (var item in items) {
    if (item is Directory) {
      fundNames.add(item.uri.pathSegments.last);
    }
  }
  if (fundNames.isEmpty) {
    print('No funds available.');
    return null;
  }
  print('Available funds:');
  for (int i = 0; i < fundNames.length; i++) {
    print('${i + 1}. ${fundNames[i]}');
  }
  int choice = -1;
  while (choice < 1 || choice > fundNames.length) {
    choice = _getIntInputGlobal('Enter the number of the fund to load: ');
  }
  return '$baseDir/${fundNames[choice - 1]}';
}

/// Global utility for integer input (used in chooseFundToLoad).
int _getIntInputGlobal(String prompt) {
  while (true) {
    stdout.write(prompt);
    String? input = stdin.readLineSync();
    try {
      int value = int.parse(input ?? '');
      return value;
    } catch (e) {
      print('Invalid input. Please enter an integer.');
    }
  }
}

void main() {
  // Ensure base directory exists.
  Directory(baseDir).createSync(recursive: true);

  FundManager fm = FundManager();
  print('--- Chit Fund System ---');
  print('1. Create New Fund');
  print('2. Load Existing Fund');
  print('3. View Existing Funds');
  stdout.write('Enter your choice: ');
  String? mainChoice = stdin.readLineSync();
  if (mainChoice == '1') {
    fm.createNewFund();
  } else if (mainChoice == '2') {
    String? fundFolder = chooseFundToLoad();
    if (fundFolder == null) {
      print('No fund loaded. Exiting.');
      exit(0);
    }
    fm.folderPath = fundFolder;
    if (!fm.loadFund()) {
      print('Error loading fund.');
      exit(0);
    }
    fm.loadMembers();
    fm.loadTransactions();
    fm.loadState();
    print('Fund loaded successfully.');
  } else if (mainChoice == '3') {
    viewExistingFunds();
    exit(0);
  } else {
    print('Invalid choice. Exiting.');
    exit(0);
  }
  fm.fundMenu();
}
