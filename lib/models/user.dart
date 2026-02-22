class User {
  final int id;
  final String? email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? patronymic;
  final Map<String, dynamic> rawData;

  User({
    required this.id,
    this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.patronymic,
    required this.rawData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      email: json['email']?.toString(),
      username: json['username']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      patronymic: json['patronymic']?.toString(),
      rawData: json,
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username ?? 'Пользователь';
  }

  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      return firstName![0].toUpperCase();
    }
    return username?[0].toUpperCase() ?? 'U';
  }
}