class ApiConfig {
  static const String baseUrl = 'https://shoppy-backend-1j34.onrender.com';

  //temporary jwt token for testing purposes
  static const String jwtToken =
      'eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJ0b2lsYWtoYW5oMTgwODA1QGdtYWlsLmNvbSIsImlkIjoxNCwicm9sZSI6IlNFTExFUiIsImlhdCI6MTc5NDA0NzE2NiwiZXhwIjoxNzk0MTMzNTY2fQ.N1k7m0QXc-kA7FWaCgJ_-TpYTQIn53l9iSKxsWP-3StrsAWTIih9JELBT2WoWgmV73Gx-EaKhawpOV0bkbvTVg';
  // Dán JWT của tài khoản SHIPPER vào đây, không thêm chữ "Bearer ".
  static const String shipperJwtToken =
      'eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJsYWtoYW5oMTgwODA1QGdtYWlsLmNvbSIsImlkIjoxNiwicm9sZSI6IkNVU1RPTUVSIiwiaWF0IjoxNzk0MDU0NDkzLCJleHAiOjE3OTQxNDA4OTN9.gqswXhkr3vbSW_Do6Vp0DdDBzLG8fJs_yMUfD92jxtFCpCVg2H-2K7m7I7e8cIWUVcNFUbHjsGXbERHat963aQ';
}
