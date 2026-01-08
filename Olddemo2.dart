import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';

// --- CORS Configuration ---
final Map<String, Object> _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
  'Content-Type': 'application/json',
};

Response _ok(dynamic body) => Response.ok(jsonEncode(body), headers: _corsHeaders);
Response _error(String msg, {int status = 500}) => Response.internalServerError(body: jsonEncode({'error': msg}), headers: _corsHeaders);

void main() async {
  // --- Database Connection ---
  final connection = await Connection.open(
    Endpoint(
      host: 'localhost',
      database: 'pieces_db',
      username: 'postgres',
      password: 'password', // ⚠️ CHANGE THIS TO YOUR SQL PASSWORD
      port: 5432,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  final app = Router();

  // Handle CORS Preflight requests
  app.options('/<ignored|.*>', (Request request) => Response.ok('', headers: _corsHeaders));

  // ============================
  // 🔐 AUTHENTICATION
  // ============================

  // 1. REGISTER
  app.post('/register', (Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      final name = payload['name'];
      final email = payload['email'];
      final password = payload['password'];

      // Check if exists
      final check = await connection.execute(
        Sql.named('SELECT id FROM users WHERE email = @email'),
        parameters: {'email': email},
      );
      if (check.isNotEmpty) return _error("Email already exists", status: 400);

      await connection.execute(
        Sql.named('INSERT INTO users (name, email, password, rating) VALUES (@n, @e, @p, 0.0)'),
        parameters: {'n': name, 'e': email, 'p': password},
      );
      return _ok({'message': 'User registered successfully'});
    } catch (e) {
      return _error("Registration failed: $e");
    }
  });

  // 2. LOGIN
  app.post('/login', (Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      final email = payload['email'];
      final password = payload['password'];

      final result = await connection.execute(
        Sql.named('SELECT id, name, rating FROM users WHERE email = @e AND password = @p'),
        parameters: {'e': email, 'p': password},
      );

      if (result.isEmpty) {
        return _error("Invalid credentials", status: 401);
      }

      final user = result.first;
      return _ok({
        'id': user[0],
        'name': user[1],
        'rating': user[2],
        'message': 'Login successful'
      });
    } catch (e) {
      return _error("Login error");
    }
  });

  // ============================
  // 🛍️ PRODUCTS & SELLING
  // ============================

  // 3. GET ALL PRODUCTS (Home Page)
  app.get('/products', (Request request) async {
    try {
      // Joins with User table to get Seller Name
      final result = await connection.execute(
        "SELECT p.id, p.name, p.description, p.image_url, p.current_price, p.end_time, u.name as seller_name, u.rating "
        "FROM products p JOIN users u ON p.seller_id = u.id "
        "WHERE p.is_sold = FALSE ORDER BY p.id DESC"
      );

      final products = result.map((row) => {
        'id': row[0],
        'name': row[1],
        'description': row[2],
        'imageUrl': row[3],
        'currentPrice': row[4],
        'endTime': row[5].toString(),
        'sellerName': row[6],
        'sellerRating': row[7],
      }).toList();
      return _ok(products);
    } catch (e) {
      print(e);
      return _error("Database error");
    }
  });

  // 4. SEARCH
  app.get('/search', (Request request) async {
    final query = request.url.queryParameters['q'] ?? '';
    try {
      final result = await connection.execute(
        Sql.named(
          "SELECT p.id, p.name, p.description, p.image_url, p.current_price, u.name, u.rating, p.end_time "
          "FROM products p JOIN users u ON p.seller_id = u.id "
          "WHERE p.name ILIKE @q OR p.description ILIKE @q"
        ),
        parameters: {'q': '%$query%'},
      );
      final products = result.map((row) => {
        'id': row[0],
        'name': row[1],
        'description': row[2],
        'imageUrl': row[3],
        'currentPrice': row[4],
        'sellerName': row[5],
        'sellerRating': row[6],
        'endTime': row[7].toString(),
      }).toList();
      return _ok(products);
    } catch (e) {
      return _error("Search failed");
    }
  });

  // 5. SELL PRODUCT (Add Item)
  app.post('/products', (Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      // Expecting: sellerId, name, category, description, imageUrl, startPrice, durationInHours

      final endTime = DateTime.now().add(Duration(hours: int.parse(payload['duration'].toString())));

      await connection.execute(
        Sql.named(
          'INSERT INTO products (seller_id, name, category, description, image_url, start_price, current_price, end_time) '
          'VALUES (@uid, @name, @cat, @desc, @img, @price, @price, @end)'
        ),
        parameters: {
          'uid': payload['sellerId'],
          'name': payload['name'],
          'cat': payload['category'],
          'desc': payload['description'],
          'img': payload['imageUrl'],
          'price': payload['startPrice'],
          'end': endTime
        },
      );
      return _ok({'message': 'Product listed successfully'});
    } catch (e) {
      print(e);
      return _error("Failed to list product");
    }
  });

  // ============================
  // 💰 BIDDING
  // ============================

  // 6. GET BIDS FOR PRODUCT
  app.get('/bids/<productId>', (Request request, String productId) async {
    try {
      final result = await connection.execute(
        Sql.named(
          "SELECT b.amount, b.timestamp, u.name "
          "FROM bids b JOIN users u ON b.user_id = u.id "
          "WHERE b.product_id = @id ORDER BY b.amount DESC"
        ),
        parameters: {'id': int.parse(productId)},
      );

      final bids = result.map((row) => {
        'amount': row[0],
        'time': row[1].toString(),
        'userName': row[2], // Show who bid
      }).toList();

      return _ok(bids);
    } catch (e) {
      return _error("Failed to fetch bids");
    }
  });

  // 7. PLACE BID
  app.post('/bid', (Request request) async {
    try {
      final payload = jsonDecode(await request.readAsString());
      final productId = payload['productId'];
      final userId = payload['userId'];
      final amount = payload['amount'];

      // 1. Validate Bid Amount vs Current Price
      final priceCheck = await connection.execute(
        Sql.named("SELECT current_price FROM products WHERE id = @id"),
        parameters: {'id': productId},
      );

      if (priceCheck.isEmpty) return _error("Product not found");
      double currentPrice = double.parse(priceCheck.first[0].toString());

      if (amount <= currentPrice) {
        return _error("Bid must be higher than current price");
      }

      // 2. Insert Bid
      await connection.execute(
        Sql.named('INSERT INTO bids (product_id, user_id, amount) VALUES (@pid, @uid, @amt)'),
        parameters: {'pid': productId, 'uid': userId, 'amt': amount},
      );

      // 3. Update Product Price
      await connection.execute(
        Sql.named('UPDATE products SET current_price = @amt WHERE id = @id'),
        parameters: {'amt': amount, 'id': productId},
      );

      return _ok({'message': 'Bid Accepted'});
    } catch (e) {
      print("Bid Error: $e");
      return _error("Failed to place bid");
    }
  });

  // 8. GET ORDERS (Winning Bids for User)
  app.get('/orders/<userId>', (Request request, String userId) async {
    try {
      // Logic: If current time > end_time AND user is the highest bidder
      final result = await connection.execute(
        Sql.named(
           "SELECT p.name, p.image_url, p.current_price, p.end_time "
           "FROM products p "
           "JOIN bids b ON p.id = b.product_id "
           "WHERE b.user_id = @uid "
           "AND b.amount = p.current_price " // User holds the highest price
           "AND p.end_time < NOW()" // Auction is over
        ),
        parameters: {'uid': int.parse(userId)},
      );

      final orders = result.map((row) => {
        'name': row[0],
        'imageUrl': row[1],
        'price': row[2],
        'date': row[3].toString(),
      }).toList();

      return _ok(orders);
    } catch (e) {
      print(e);
      return _error("Failed to fetch orders");
    }
  });

  final server = await io.serve(app, '0.0.0.0', 8081);
  print('🚀 Server running on port 8081');
}
