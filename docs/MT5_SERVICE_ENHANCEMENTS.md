# MT5 Service API Enhancements

## Overview

This document outlines the additional endpoints and functionality that need to be added to the MT5 service (`/Users/tbrtv/Desktop/dev/mt5_service`) to fully support all features currently used by btrade's direct MT5 integration.

**Status**: All features are supported by the MetaTrader5 Python library and can be easily added following the existing service patterns.

---

## Missing Features Analysis

### Current MT5 Service Coverage
✅ Market orders  
✅ Position management (get, close, modify SL/TP)  
✅ Market data (symbol info, ticks, historical)  
✅ History (deals, orders)  
✅ Health monitoring  

### Missing Features (Required by btrade)
❌ Account information  
❌ Cancel pending orders  
❌ Limit orders  
❌ Symbol selection  
❌ Terminal information  
❌ Position count endpoint  
❌ Enhanced history endpoints (deal/order by ticket)  
❌ Enhanced data fetching (position-based, range-based)  
❌ Error debugging endpoints  

---

## 1. Account Information Endpoint

### Endpoint Specification

**Route**: `GET /account_info`

**Description**: Retrieve comprehensive account information including balance, equity, margin, leverage, and trading status.

**Response Schema**:
```json
{
  "login": 12345678,
  "server": "Exness-MT5Trial9",
  "balance": 10000.0,
  "equity": 10050.0,
  "margin": 500.0,
  "margin_free": 9550.0,
  "margin_level": 2010.0,
  "profit": 50.0,
  "currency": "USD",
  "leverage": 500,
  "trade_mode": 0,
  "trade_allowed": true,
  "trade_expert": true,
  "margin_so_mode": 0,
  "margin_so_call": 50.0,
  "margin_so_so": 30.0,
  "margin_initial": 0.0,
  "margin_maintenance": 0.0,
  "assets": 0.0,
  "liabilities": 0.0,
  "commission_blocked": 0.0,
  "name": "Account Name",
  "company": "Exness"
}
```

**Implementation**:

**File**: `app/routes/account.py` (new file)

```python
from flask import Blueprint, jsonify
import MetaTrader5 as mt5
import logging
from flasgger import swag_from

account_bp = Blueprint('account', __name__)
logger = logging.getLogger(__name__)

@account_bp.route('/account_info', methods=['GET'])
@swag_from({
    'tags': ['Account'],
    'responses': {
        200: {
            'description': 'Account information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'login': {'type': 'integer'},
                    'server': {'type': 'string'},
                    'balance': {'type': 'number'},
                    'equity': {'type': 'number'},
                    'margin': {'type': 'number'},
                    'margin_free': {'type': 'number'},
                    'margin_level': {'type': 'number'},
                    'profit': {'type': 'number'},
                    'currency': {'type': 'string'},
                    'leverage': {'type': 'integer'},
                    'trade_mode': {'type': 'integer'},
                    'trade_allowed': {'type': 'boolean'},
                    'trade_expert': {'type': 'boolean'},
                    'name': {'type': 'string'},
                    'company': {'type': 'string'}
                }
            }
        },
        400: {
            'description': 'Failed to retrieve account information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_account_info():
    """
    Get Account Information
    ---
    description: Retrieve comprehensive account information including balance, equity, margin, and trading status.
    """
    try:
        account_info = mt5.account_info()
        if account_info is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get account information",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to dictionary
        account_dict = account_info._asdict()
        
        return jsonify(account_dict), 200
    
    except Exception as e:
        logger.error(f"Error in get_account_info: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

**Registration**: Add to `app/app.py`:
```python
from routes.account import account_bp
app.register_blueprint(account_bp)
```

---

## 2. Cancel Order Endpoint

### Endpoint Specification

**Route**: `POST /cancel_order` or `DELETE /order/{order_id}`

**Description**: Cancel a pending order (limit, stop, or stop-limit order).

**Request Body**:
```json
{
  "order_id": 123456789
}
```

**Response Schema**:
```json
{
  "message": "Order cancelled successfully",
  "result": {
    "retcode": 10009,
    "order": 123456789,
    "request_id": 1,
    "retcode_external": 0,
    "comment": "Request executed",
    "request": {
      "action": 5,
      "order": 123456789
    }
  }
}
```

**Implementation**:

**File**: `app/routes/order.py` (add to existing file)

```python
@order_bp.route('/cancel_order', methods=['POST'])
@swag_from({
    'tags': ['Order'],
    'parameters': [
        {
            'name': 'body',
            'in': 'body',
            'required': True,
            'schema': {
                'type': 'object',
                'properties': {
                    'order_id': {'type': 'integer'}
                },
                'required': ['order_id']
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Order cancelled successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'result': {
                        'type': 'object',
                        'properties': {
                            'retcode': {'type': 'integer'},
                            'order': {'type': 'integer'},
                            'comment': {'type': 'string'}
                        }
                    }
                }
            }
        },
        400: {
            'description': 'Bad request or failed to cancel order.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def cancel_order_endpoint():
    """
    Cancel Pending Order
    ---
    description: Cancel a pending order (limit, stop, or stop-limit order).
    """
    try:
        data = request.get_json()
        if not data or 'order_id' not in data:
            return jsonify({"error": "Order ID is required"}), 400
        
        order_id = int(data['order_id'])
        
        # Build cancel request
        request_data = {
            "action": mt5.TRADE_ACTION_REMOVE,
            "order": order_id
        }
        
        # Send cancel request
        result = mt5.order_send(request_data)
        
        if result is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to cancel order",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            return jsonify({
                "error": f"Order cancellation failed: {result.comment}",
                "mt5_error": mt5.last_error()[1],
                "result": result._asdict()
            }), 400
        
        return jsonify({
            "message": "Order cancelled successfully",
            "result": result._asdict()
        }), 200
    
    except ValueError:
        return jsonify({"error": "Invalid order ID format"}), 400
    except Exception as e:
        logger.error(f"Error in cancel_order: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 3. Limit Orders Support

### Endpoint Specification

**Option A**: Extend existing `/order` endpoint to support limit orders  
**Option B**: Create new `/order_limit` endpoint

**Recommended**: Extend existing `/order` endpoint (Option A)

**Updated Request Body** (for `/order` endpoint):
```json
{
  "symbol": "EURUSD",
  "volume": 0.1,
  "type": "BUY_LIMIT",  // or "SELL_LIMIT", "BUY_STOP", "SELL_STOP"
  "price": 1.1000,       // Required for limit/stop orders
  "deviation": 20,
  "magic": 0,
  "comment": "",
  "type_filling": "ORDER_FILLING_IOC",
  "sl": 1.0950,
  "tp": 1.1100,
  "expiration": "2024-12-31T23:59:59Z"  // Optional, ISO format
}
```

**Order Type Enum**:
- `BUY` - Market buy order
- `SELL` - Market sell order
- `BUY_LIMIT` - Buy limit order
- `SELL_LIMIT` - Sell limit order
- `BUY_STOP` - Buy stop order
- `SELL_STOP` - Sell stop order
- `BUY_STOP_LIMIT` - Buy stop limit order
- `SELL_STOP_LIMIT` - Sell stop limit order

**Implementation**:

**File**: `app/routes/order.py` (modify existing `send_market_order_endpoint`)

```python
@order_bp.route('/order', methods=['POST'])
@swag_from({
    'tags': ['Order'],
    'parameters': [
        {
            'name': 'body',
            'in': 'body',
            'required': True,
            'schema': {
                'type': 'object',
                'properties': {
                    'symbol': {'type': 'string'},
                    'volume': {'type': 'number'},
                    'type': {
                        'type': 'string',
                        'enum': [
                            'BUY', 'SELL',
                            'BUY_LIMIT', 'SELL_LIMIT',
                            'BUY_STOP', 'SELL_STOP',
                            'BUY_STOP_LIMIT', 'SELL_STOP_LIMIT'
                        ]
                    },
                    'price': {'type': 'number'},  // Required for limit/stop orders
                    'deviation': {'type': 'integer', 'default': 20},
                    'magic': {'type': 'integer', 'default': 0},
                    'comment': {'type': 'string', 'default': ''},
                    'type_filling': {
                        'type': 'string',
                        'enum': ['ORDER_FILLING_IOC', 'ORDER_FILLING_FOK', 'ORDER_FILLING_RETURN']
                    },
                    'sl': {'type': 'number'},
                    'tp': {'type': 'number'},
                    'expiration': {'type': 'string', 'format': 'date-time'}  // Optional
                },
                'required': ['symbol', 'volume', 'type']
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Order executed/placed successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'result': {
                        'type': 'object',
                        'properties': {
                            'retcode': {'type': 'integer'},
                            'order': {'type': 'integer'},
                            'magic': {'type': 'integer'},
                            'price': {'type': 'number'},
                            'symbol': {'type': 'string'}
                        }
                    }
                }
            }
        },
        400: {
            'description': 'Bad request or order failed.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def send_order_endpoint():
    """
    Send Order (Market, Limit, or Stop)
    ---
    description: Execute a market order or place a pending order (limit/stop).
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Order data is required"}), 400

        required_fields = ['symbol', 'volume', 'type']
        if not all(field in data for field in required_fields):
            return jsonify({"error": "Missing required fields"}), 400

        # Map order types to MT5 constants
        order_type_map = {
            'BUY': mt5.ORDER_TYPE_BUY,
            'SELL': mt5.ORDER_TYPE_SELL,
            'BUY_LIMIT': mt5.ORDER_TYPE_BUY_LIMIT,
            'SELL_LIMIT': mt5.ORDER_TYPE_SELL_LIMIT,
            'BUY_STOP': mt5.ORDER_TYPE_BUY_STOP,
            'SELL_STOP': mt5.ORDER_TYPE_SELL_STOP,
            'BUY_STOP_LIMIT': mt5.ORDER_TYPE_BUY_STOP_LIMIT,
            'SELL_STOP_LIMIT': mt5.ORDER_TYPE_SELL_STOP_LIMIT
        }

        order_type_str = data['type']
        if order_type_str not in order_type_map:
            return jsonify({"error": f"Invalid order type: {order_type_str}"}), 400

        mt5_order_type = order_type_map[order_type_str]

        # Determine if this is a market order or pending order
        is_market_order = order_type_str in ['BUY', 'SELL']
        is_pending_order = not is_market_order

        # Build request
        request_data = {
            "action": mt5.TRADE_ACTION_DEAL if is_market_order else mt5.TRADE_ACTION_PENDING,
            "symbol": data['symbol'],
            "volume": float(data['volume']),
            "type": mt5_order_type,
            "deviation": data.get('deviation', 20),
            "magic": data.get('magic', 0),
            "comment": data.get('comment', ''),
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": data.get('type_filling', mt5.ORDER_FILLING_IOC),
        }

        # For market orders, get current price
        if is_market_order:
            tick = mt5.symbol_info_tick(data['symbol'])
            if tick is None:
                return jsonify({"error": "Failed to get symbol price"}), 400

            if order_type_str == 'BUY':
                request_data["price"] = tick.ask
            else:  # SELL
                request_data["price"] = tick.bid
        else:
            # For pending orders, price is required
            if 'price' not in data:
                return jsonify({"error": "Price is required for limit/stop orders"}), 400
            request_data["price"] = float(data['price'])

        # Add expiration if provided (for pending orders)
        if 'expiration' in data and is_pending_order:
            from datetime import datetime
            try:
                expiration = datetime.fromisoformat(data['expiration'].replace('Z', '+00:00'))
                request_data["expiration"] = expiration
            except ValueError:
                return jsonify({"error": "Invalid expiration format. Use ISO 8601 format"}), 400

        # Add optional SL/TP if provided
        if 'sl' in data:
            request_data["sl"] = float(data['sl'])
        if 'tp' in data:
            request_data["tp"] = float(data['tp'])

        # Send order
        result = mt5.order_send(request_data)
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            error_code, error_str = mt5.last_error()
            
            return jsonify({
                "error": f"Order failed: {result.comment}",
                "mt5_error": error_str,
                "result": result._asdict()
            }), 400

        action_word = "executed" if is_market_order else "placed"
        return jsonify({
            "message": f"Order {action_word} successfully",
            "result": result._asdict()
        }), 200
    
    except Exception as e:
        logger.error(f"Error in send_order: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 4. Symbol Selection Endpoint

### Endpoint Specification

**Route**: `POST /symbol_select/{symbol}` or `POST /symbol_select`

**Description**: Select/enable a symbol in the Market Watch window. This ensures the symbol is available for trading operations.

**Request Body** (if using POST with body):
```json
{
  "symbol": "EURUSD",
  "enable": true
}
```

**Response Schema**:
```json
{
  "message": "Symbol selected successfully",
  "symbol": "EURUSD",
  "selected": true
}
```

**Implementation**:

**File**: `app/routes/symbol.py` (add to existing file)

```python
@symbol_bp.route('/symbol_select/<symbol>', methods=['POST'])
@swag_from({
    'tags': ['Symbol'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'path',
            'type': 'string',
            'required': True,
            'description': 'Symbol name to select.'
        },
        {
            'name': 'body',
            'in': 'body',
            'required': False,
            'schema': {
                'type': 'object',
                'properties': {
                    'enable': {'type': 'boolean', 'default': True}
                }
            }
        }
    ],
    'responses': {
        200: {
            'description': 'Symbol selection status.',
            'schema': {
                'type': 'object',
                'properties': {
                    'message': {'type': 'string'},
                    'symbol': {'type': 'string'},
                    'selected': {'type': 'boolean'}
                }
            }
        },
        400: {
            'description': 'Failed to select symbol.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def symbol_select_endpoint(symbol):
    """
    Select Symbol
    ---
    description: Select/enable a symbol in the Market Watch window.
    """
    try:
        data = request.get_json() or {}
        enable = data.get('enable', True)
        
        result = mt5.symbol_select(symbol, enable)
        
        if not result:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": f"Failed to select symbol {symbol}",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        action = "selected" if enable else "deselected"
        return jsonify({
            "message": f"Symbol {action} successfully",
            "symbol": symbol,
            "selected": result
        }), 200
    
    except Exception as e:
        logger.error(f"Error in symbol_select: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 5. Terminal Information Endpoint

### Endpoint Specification

**Route**: `GET /terminal_info`

**Description**: Retrieve terminal information including connection status, build number, and terminal capabilities.

**Response Schema**:
```json
{
  "name": "MetaTrader 5",
  "company": "MetaQuotes Software Corp.",
  "path": "/path/to/terminal",
  "data_path": "/path/to/data",
  "common_path": "/path/to/common",
  "build": 3815,
  "max_bars": 65536,
  "codepage": 1252,
  "ping_last": 45,
  "community_account": 0,
  "community_connection": false,
  "connected": true,
  "trade_allowed": true,
  "tradeapi_disabled": false,
  "email_enabled": true,
  "ftp_enabled": true,
  "notifications_enabled": true,
  "mqid": false,
  "balance": 0.0,
  "equity": 0.0,
  "margin_free": 0.0,
  "margin_level": 0.0,
  "profit": 0.0,
  "margin": 0.0,
  "margin_so_call": 0.0,
  "margin_so_so": 0.0,
  "margin_initial": 0.0,
  "margin_maintenance": 0.0,
  "assets": 0.0,
  "liabilities": 0.0,
  "commission_blocked": 0.0,
  "name": "",
  "server": "",
  "currency": "",
  "company": ""
}
```

**Implementation**:

**File**: `app/routes/health.py` (add to existing file) or create `app/routes/terminal.py`

**Option 1**: Add to health.py (recommended, as it's related to system status)

```python
@health_bp.route('/terminal_info', methods=['GET'])
@swag_from({
    'tags': ['Health'],
    'responses': {
        200: {
            'description': 'Terminal information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'name': {'type': 'string'},
                    'company': {'type': 'string'},
                    'path': {'type': 'string'},
                    'build': {'type': 'integer'},
                    'connected': {'type': 'boolean'},
                    'trade_allowed': {'type': 'boolean'},
                    'ping_last': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Failed to retrieve terminal information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_terminal_info():
    """
    Get Terminal Information
    ---
    description: Retrieve terminal information including connection status and capabilities.
    """
    try:
        terminal_info = mt5.terminal_info()
        if terminal_info is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get terminal information",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to dictionary
        terminal_dict = terminal_info._asdict()
        
        return jsonify(terminal_dict), 200
    
    except Exception as e:
        logger.error(f"Error in get_terminal_info: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 6. Get Pending Orders Endpoint (Bonus)

### Endpoint Specification

**Route**: `GET /get_orders` or `GET /get_pending_orders`

**Description**: Retrieve all pending orders (limit, stop orders that haven't been executed yet).

**Query Parameters**:
- `magic` (optional): Filter by magic number

**Response Schema**:
```json
{
  "orders": [
    {
      "ticket": 123456789,
      "time_setup": "2024-01-01T12:00:00Z",
      "type": 2,
      "type_time": 0,
      "type_filling": 2,
      "volume_initial": 0.1,
      "volume_current": 0.1,
      "price_open": 1.1000,
      "sl": 1.0950,
      "tp": 1.1100,
      "price_current": 1.1005,
      "price_stoplimit": 0.0,
      "symbol": "EURUSD",
      "comment": "",
      "magic": 400000,
      "time_expiration": 0,
      "time_done": 0,
      "time_setup_msc": 1704110400000,
      "time_done_msc": 0,
      "time_expiration_msc": 0,
      "type_filling": 2,
      "type_time": 0,
      "reason": 3,
      "state": 1,
      "volume_initial": 0.1,
      "volume_current": 0.1,
      "price_open": 1.1000,
      "price_current": 1.1005,
      "price_stoplimit": 0.0,
      "sl": 1.0950,
      "tp": 1.1100,
      "time_setup": 1704110400,
      "time_expiration": 0,
      "time_done": 0,
      "time_setup_msc": 1704110400000,
      "time_done_msc": 0,
      "time_expiration_msc": 0,
      "type": 2,
      "type_filling": 2,
      "type_time": 0,
      "reason": 3,
      "state": 1,
      "magic": 400000,
      "position_id": 0,
      "position_by_id": 0,
      "comment": "",
      "external_id": ""
    }
  ],
  "total": 1
}
```

**Implementation**:

**File**: `app/routes/order.py` (add to existing file)

```python
@order_bp.route('/get_orders', methods=['GET'])
@swag_from({
    'tags': ['Order'],
    'parameters': [
        {
            'name': 'magic',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'description': 'Magic number to filter orders.'
        }
    ],
    'responses': {
        200: {
            'description': 'Pending orders retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'orders': {
                        'type': 'array',
                        'items': {'type': 'object'}
                    },
                    'total': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Failed to retrieve orders.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_orders_endpoint():
    """
    Get Pending Orders
    ---
    description: Retrieve all pending orders (limit, stop orders).
    """
    try:
        magic = request.args.get('magic', type=int)
        
        # Get all orders
        if magic is not None:
            orders = mt5.orders_get(magic=magic)
        else:
            orders = mt5.orders_get()
        
        if orders is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to retrieve orders",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400
        
        # Convert to list of dictionaries
        orders_list = [order._asdict() for order in orders]
        
        # Convert time fields to ISO format
        for order_dict in orders_list:
            if 'time_setup' in order_dict:
                order_dict['time_setup'] = datetime.fromtimestamp(
                    order_dict['time_setup'], tz=mt5.TIMEZONE
                ).isoformat()
            if 'time_expiration' in order_dict and order_dict['time_expiration'] > 0:
                order_dict['time_expiration'] = datetime.fromtimestamp(
                    order_dict['time_expiration'], tz=mt5.TIMEZONE
                ).isoformat()
            if 'time_done' in order_dict and order_dict['time_done'] > 0:
                order_dict['time_done'] = datetime.fromtimestamp(
                    order_dict['time_done'], tz=mt5.TIMEZONE
                ).isoformat()
        
        return jsonify({
            "orders": orders_list,
            "total": len(orders_list)
        }), 200
    
    except Exception as e:
        logger.error(f"Error in get_orders: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 7. Position Count Endpoint

### Endpoint Specification

**Route**: `GET /positions_total`

**Description**: Retrieve the total number of open trading positions. Useful for quick position count checks without fetching full position data.

**Response Schema**:
```json
{
  "total": 5
}
```

**Implementation**:

**File**: `app/routes/position.py` (add to existing file)

```python
@position_bp.route('/positions_total', methods=['GET'])
@swag_from({
    'tags': ['Position'],
    'responses': {
        200: {
            'description': 'Total number of open positions retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'total': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Failed to get positions total.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def positions_total_endpoint():
    """
    Get Total Open Positions
    ---
    description: Retrieve the total number of open trading positions.
    """
    try:
        total = mt5.positions_total()
        if total is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get positions total",
                "mt5_error": error_str,
                "error_code": error_code
            }), 400

        return jsonify({"total": total}), 200

    except Exception as e:
        logger.error(f"Error in positions_total: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 8. Enhanced History Endpoints

### 8.1 Get Deal from Ticket

**Route**: `GET /get_deal_from_ticket`

**Description**: Retrieve deal information associated with a specific ticket number.

**Query Parameters**:
- `ticket` (required): Deal ticket number

**Response Schema**:
```json
{
  "ticket": 123456789,
  "symbol": "EURUSD",
  "type": "BUY",
  "volume": 0.1,
  "open_time": "2024-01-01T12:00:00Z",
  "close_time": "2024-01-01T13:00:00Z",
  "open_price": 1.1000,
  "close_price": 1.1050,
  "profit": 50.0,
  "commission": 0.5,
  "swap": 0.0,
  "comment": ""
}
```

**Implementation**:

**File**: `app/routes/history.py` (add to existing file or create new)

```python
@history_bp.route('/get_deal_from_ticket', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'ticket',
            'in': 'query',
            'type': 'integer',
            'required': True,
            'description': 'Ticket number to retrieve deal information.'
        }
    ],
    'responses': {
        200: {
            'description': 'Deal information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'ticket': {'type': 'integer'},
                    'symbol': {'type': 'string'},
                    'type': {'type': 'string'},
                    'volume': {'type': 'number'},
                    'open_time': {'type': 'string', 'format': 'date-time'},
                    'close_time': {'type': 'string', 'format': 'date-time'},
                    'open_price': {'type': 'number'},
                    'close_price': {'type': 'number'},
                    'profit': {'type': 'number'},
                    'commission': {'type': 'number'},
                    'swap': {'type': 'number'},
                    'comment': {'type': 'string'}
                }
            }
        },
        400: {
            'description': 'Invalid ticket format.'
        },
        404: {
            'description': 'Failed to get deal information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_deal_from_ticket_endpoint():
    """
    Get Deal Information from Ticket
    ---
    description: Retrieve deal information associated with a specific ticket number.
    """
    try:
        ticket = request.args.get('ticket')
        if not ticket:
            return jsonify({"error": "Ticket parameter is required"}), 400
        
        ticket = int(ticket)
        
        # Get deal by ticket
        deals = mt5.history_deals_get(ticket=ticket)
        if deals is None or len(deals) == 0:
            return jsonify({"error": "Failed to get deal information"}), 404
        
        # Process deal data
        deal = deals[0]
        deal_dict = deal._asdict()
        
        # Convert timestamps to ISO format
        from datetime import datetime
        if 'time' in deal_dict and deal_dict['time'] > 0:
            deal_dict['time'] = datetime.fromtimestamp(
                deal_dict['time'], tz=mt5.TIMEZONE
            ).isoformat()
        
        return jsonify(deal_dict), 200
    
    except ValueError:
        return jsonify({"error": "Invalid ticket format"}), 400
    except Exception as e:
        logger.error(f"Error in get_deal_from_ticket: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

### 8.2 Get Order from Ticket

**Route**: `GET /get_order_from_ticket`

**Description**: Retrieve order information associated with a specific ticket number.

**Query Parameters**:
- `ticket` (required): Order ticket number

**Response Schema**:
```json
{
  "ticket": 123456789,
  "time_setup": "2024-01-01T12:00:00Z",
  "type": 2,
  "volume_initial": 0.1,
  "price_open": 1.1000,
  "sl": 1.0950,
  "tp": 1.1100,
  "symbol": "EURUSD",
  "comment": "",
  "magic": 400000
}
```

**Implementation**:

**File**: `app/routes/history.py` (add to existing file)

```python
@history_bp.route('/get_order_from_ticket', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'ticket',
            'in': 'query',
            'type': 'integer',
            'required': True,
            'description': 'Ticket number to retrieve order information.'
        }
    ],
    'responses': {
        200: {
            'description': 'Order information retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'ticket': {'type': 'integer'},
                    'time_setup': {'type': 'string', 'format': 'date-time'},
                    'type': {'type': 'integer'},
                    'volume_initial': {'type': 'number'},
                    'price_open': {'type': 'number'},
                    'symbol': {'type': 'string'},
                    'magic': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Invalid ticket format.'
        },
        404: {
            'description': 'Failed to get order information.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def get_order_from_ticket_endpoint():
    """
    Get Order Information from Ticket
    ---
    description: Retrieve order information associated with a specific ticket number.
    """
    try:
        ticket = request.args.get('ticket')
        if not ticket:
            return jsonify({"error": "Ticket parameter is required"}), 400
        
        ticket = int(ticket)
        
        # Get order by ticket
        orders = mt5.history_orders_get(ticket=ticket)
        if orders is None or len(orders) == 0:
            return jsonify({"error": "Failed to get order information"}), 404
        
        # Process order data
        order = orders[0]
        order_dict = order._asdict()
        
        # Convert timestamps to ISO format
        from datetime import datetime
        if 'time_setup' in order_dict and order_dict['time_setup'] > 0:
            order_dict['time_setup'] = datetime.fromtimestamp(
                order_dict['time_setup'], tz=mt5.TIMEZONE
            ).isoformat()
        if 'time_expiration' in order_dict and order_dict['time_expiration'] > 0:
            order_dict['time_expiration'] = datetime.fromtimestamp(
                order_dict['time_expiration'], tz=mt5.TIMEZONE
            ).isoformat()
        if 'time_done' in order_dict and order_dict['time_done'] > 0:
            order_dict['time_done'] = datetime.fromtimestamp(
                order_dict['time_done'], tz=mt5.TIMEZONE
            ).isoformat()
        
        return jsonify(order_dict), 200
    
    except ValueError:
        return jsonify({"error": "Invalid ticket format"}), 400
    except Exception as e:
        logger.error(f"Error in get_order_from_ticket: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

### 8.3 History Deals Get (Enhanced)

**Route**: `GET /history_deals_get`

**Description**: Retrieve historical deals within a specified date range, optionally filtered by position.

**Query Parameters**:
- `from_date` (required): Start date in ISO format
- `to_date` (required): End date in ISO format
- `position` (optional): Position ID to filter deals

**Response Schema**:
```json
{
  "deals": [
    {
      "ticket": 123456789,
      "position_id": 987654321,
      "time": "2024-01-01T12:00:00Z",
      "type": 0,
      "entry": 0,
      "volume": 0.1,
      "price": 1.1000,
      "profit": 50.0,
      "commission": 0.5,
      "swap": 0.0,
      "symbol": "EURUSD",
      "comment": ""
    }
  ],
  "total": 1
}
```

**Implementation**:

**File**: `app/routes/history.py` (add to existing file)

```python
@history_bp.route('/history_deals_get', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'from_date',
            'in': 'query',
            'type': 'string',
            'required': True,
            'format': 'date-time',
            'description': 'Start date in ISO format.'
        },
        {
            'name': 'to_date',
            'in': 'query',
            'type': 'string',
            'required': True,
            'format': 'date-time',
            'description': 'End date in ISO format.'
        },
        {
            'name': 'position',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'description': 'Position ID to filter deals.'
        }
    ],
    'responses': {
        200: {
            'description': 'Deals history retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'deals': {
                        'type': 'array',
                        'items': {'type': 'object'}
                    },
                    'total': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Invalid parameter format or missing parameters.'
        },
        404: {
            'description': 'Failed to get deals history.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def history_deals_get_endpoint():
    """
    Get Deals History
    ---
    description: Retrieve historical deals within a specified date range, optionally filtered by position.
    """
    try:
        from_date = request.args.get('from_date')
        to_date = request.args.get('to_date')
        position = request.args.get('position')
        
        if not all([from_date, to_date]):
            return jsonify({"error": "from_date and to_date parameters are required"}), 400
        
        from datetime import datetime
        from_date = datetime.fromisoformat(from_date.replace('Z', '+00:00'))
        to_date = datetime.fromisoformat(to_date.replace('Z', '+00:00'))
        
        from_timestamp = int(from_date.timestamp())
        to_timestamp = int(to_date.timestamp())
        
        # Get deals with optional position filter
        if position:
            position = int(position)
            deals = mt5.history_deals_get(from_timestamp, to_timestamp, position=position)
        else:
            deals = mt5.history_deals_get(from_timestamp, to_timestamp)
        
        if deals is None:
            return jsonify({"error": "Failed to get deals history"}), 404
        
        # Convert to list of dictionaries
        deals_list = [deal._asdict() for deal in deals]
        
        # Convert timestamps to ISO format
        for deal_dict in deals_list:
            if 'time' in deal_dict and deal_dict['time'] > 0:
                deal_dict['time'] = datetime.fromtimestamp(
                    deal_dict['time'], tz=mt5.TIMEZONE
                ).isoformat()
        
        return jsonify({
            "deals": deals_list,
            "total": len(deals_list)
        }), 200
    
    except ValueError:
        return jsonify({"error": "Invalid parameter format"}), 400
    except Exception as e:
        logger.error(f"Error in history_deals_get: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

### 8.4 History Orders Get (Enhanced)

**Route**: `GET /history_orders_get`

**Description**: Retrieve historical orders, optionally filtered by ticket.

**Query Parameters**:
- `ticket` (optional): Order ticket to filter

**Response Schema**:
```json
{
  "orders": [
    {
      "ticket": 123456789,
      "time_setup": "2024-01-01T12:00:00Z",
      "type": 2,
      "volume_initial": 0.1,
      "price_open": 1.1000,
      "symbol": "EURUSD",
      "magic": 400000
    }
  ],
  "total": 1
}
```

**Implementation**:

**File**: `app/routes/history.py` (add to existing file)

```python
@history_bp.route('/history_orders_get', methods=['GET'])
@swag_from({
    'tags': ['History'],
    'parameters': [
        {
            'name': 'ticket',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'description': 'Ticket number to retrieve orders history.'
        }
    ],
    'responses': {
        200: {
            'description': 'Orders history retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'orders': {
                        'type': 'array',
                        'items': {'type': 'object'}
                    },
                    'total': {'type': 'integer'}
                }
            }
        },
        400: {
            'description': 'Invalid ticket format or missing parameter.'
        },
        404: {
            'description': 'Failed to get orders history.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def history_orders_get_endpoint():
    """
    Get Orders History
    ---
    description: Retrieve historical orders, optionally filtered by ticket.
    """
    try:
        ticket = request.args.get('ticket', type=int)
        
        # Get orders with optional ticket filter
        if ticket:
            orders = mt5.history_orders_get(ticket=ticket)
        else:
            orders = mt5.history_orders_get()
        
        if orders is None:
            return jsonify({"error": "Failed to get orders history"}), 404
        
        # Convert to list of dictionaries
        orders_list = [order._asdict() for order in orders]
        
        # Convert timestamps to ISO format
        from datetime import datetime
        for order_dict in orders_list:
            if 'time_setup' in order_dict and order_dict['time_setup'] > 0:
                order_dict['time_setup'] = datetime.fromtimestamp(
                    order_dict['time_setup'], tz=mt5.TIMEZONE
                ).isoformat()
            if 'time_expiration' in order_dict and order_dict['time_expiration'] > 0:
                order_dict['time_expiration'] = datetime.fromtimestamp(
                    order_dict['time_expiration'], tz=mt5.TIMEZONE
                ).isoformat()
            if 'time_done' in order_dict and order_dict['time_done'] > 0:
                order_dict['time_done'] = datetime.fromtimestamp(
                    order_dict['time_done'], tz=mt5.TIMEZONE
                ).isoformat()
        
        return jsonify({
            "orders": orders_list,
            "total": len(orders_list)
        }), 200
    
    except ValueError:
        return jsonify({"error": "Invalid ticket format"}), 400
    except Exception as e:
        logger.error(f"Error in history_orders_get: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 9. Enhanced Data Fetching Endpoints

### 9.1 Fetch Data from Position

**Route**: `GET /fetch_data_pos`

**Description**: Retrieve historical price data for a given symbol starting from a specific position (using `copy_rates_from_pos`). Useful for getting data relative to a position's entry point.

**Query Parameters**:
- `symbol` (required): Symbol name
- `timeframe` (optional): Timeframe (M1, M5, H1, etc.), default: M1
- `num_bars` (optional): Number of bars to fetch, default: 100

**Response Schema**:
```json
[
  {
    "time": "2024-01-01T12:00:00Z",
    "open": 1.1000,
    "high": 1.1010,
    "low": 1.0990,
    "close": 1.1005,
    "tick_volume": 1000,
    "spread": 2,
    "real_volume": 500
  }
]
```

**Implementation**:

**File**: `app/routes/data.py` (add to existing file or create new)

```python
@data_bp.route('/fetch_data_pos', methods=['GET'])
@swag_from({
    'tags': ['Data'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'query',
            'type': 'string',
            'required': True,
            'description': 'Symbol name to fetch data for.'
        },
        {
            'name': 'timeframe',
            'in': 'query',
            'type': 'string',
            'required': False,
            'default': 'M1',
            'description': 'Timeframe for the data (e.g., M1, M5, H1).'
        },
        {
            'name': 'num_bars',
            'in': 'query',
            'type': 'integer',
            'required': False,
            'default': 100,
            'description': 'Number of bars to fetch.'
        }
    ],
    'responses': {
        200: {
            'description': 'Data fetched successfully.',
            'schema': {
                'type': 'array',
                'items': {
                    'type': 'object',
                    'properties': {
                        'time': {'type': 'string', 'format': 'date-time'},
                        'open': {'type': 'number'},
                        'high': {'type': 'number'},
                        'low': {'type': 'number'},
                        'close': {'type': 'number'},
                        'tick_volume': {'type': 'integer'},
                        'spread': {'type': 'integer'},
                        'real_volume': {'type': 'integer'}
                    }
                }
            }
        },
        400: {
            'description': 'Invalid request parameters.'
        },
        404: {
            'description': 'Failed to get rates data.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def fetch_data_pos_endpoint():
    """
    Fetch Data from Position
    ---
    description: Retrieve historical price data for a given symbol starting from a specific position.
    """
    try:
        symbol = request.args.get('symbol')
        timeframe = request.args.get('timeframe', 'M1')
        num_bars = int(request.args.get('num_bars', 100))
        
        if not symbol:
            return jsonify({"error": "Symbol parameter is required"}), 400

        # Map timeframe string to MT5 constant
        timeframe_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1,
            'W1': mt5.TIMEFRAME_W1,
            'MN1': mt5.TIMEFRAME_MN1
        }
        
        mt5_timeframe = timeframe_map.get(timeframe.upper())
        if mt5_timeframe is None:
            return jsonify({"error": f"Invalid timeframe: {timeframe}"}), 400
        
        # Fetch data from position (0 = current position)
        rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, num_bars)
        if rates is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get rates data",
                "mt5_error": error_str,
                "error_code": error_code
            }), 404
        
        # Convert to list of dictionaries with ISO timestamps
        from datetime import datetime
        data_list = []
        for rate in rates:
            rate_dict = rate._asdict()
            if 'time' in rate_dict:
                rate_dict['time'] = datetime.fromtimestamp(
                    rate_dict['time'], tz=mt5.TIMEZONE
                ).isoformat()
            data_list.append(rate_dict)
        
        return jsonify(data_list), 200
    
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        logger.error(f"Error in fetch_data_pos: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

### 9.2 Fetch Data within Date Range

**Route**: `GET /fetch_data_range`

**Description**: Retrieve historical price data for a given symbol within a specified date range (using `copy_rates_range`).

**Query Parameters**:
- `symbol` (required): Symbol name
- `timeframe` (optional): Timeframe (M1, M5, H1, etc.), default: M1
- `start` (required): Start datetime in ISO format
- `end` (required): End datetime in ISO format

**Response Schema**:
```json
[
  {
    "time": "2024-01-01T12:00:00Z",
    "open": 1.1000,
    "high": 1.1010,
    "low": 1.0990,
    "close": 1.1005,
    "tick_volume": 1000,
    "spread": 2,
    "real_volume": 500
  }
]
```

**Implementation**:

**File**: `app/routes/data.py` (add to existing file)

```python
@data_bp.route('/fetch_data_range', methods=['GET'])
@swag_from({
    'tags': ['Data'],
    'parameters': [
        {
            'name': 'symbol',
            'in': 'query',
            'type': 'string',
            'required': True,
            'description': 'Symbol name to fetch data for.'
        },
        {
            'name': 'timeframe',
            'in': 'query',
            'type': 'string',
            'required': False,
            'default': 'M1',
            'description': 'Timeframe for the data (e.g., M1, M5, H1).'
        },
        {
            'name': 'start',
            'in': 'query',
            'type': 'string',
            'required': True,
            'format': 'date-time',
            'description': 'Start datetime in ISO format.'
        },
        {
            'name': 'end',
            'in': 'query',
            'type': 'string',
            'required': True,
            'format': 'date-time',
            'description': 'End datetime in ISO format.'
        }
    ],
    'responses': {
        200: {
            'description': 'Data fetched successfully.',
            'schema': {
                'type': 'array',
                'items': {
                    'type': 'object',
                    'properties': {
                        'time': {'type': 'string', 'format': 'date-time'},
                        'open': {'type': 'number'},
                        'high': {'type': 'number'},
                        'low': {'type': 'number'},
                        'close': {'type': 'number'},
                        'tick_volume': {'type': 'integer'},
                        'spread': {'type': 'integer'},
                        'real_volume': {'type': 'integer'}
                    }
                }
            }
        },
        400: {
            'description': 'Invalid request parameters.'
        },
        404: {
            'description': 'Failed to get rates data.'
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def fetch_data_range_endpoint():
    """
    Fetch Data within a Date Range
    ---
    description: Retrieve historical price data for a given symbol within a specified date range.
    """
    try:
        symbol = request.args.get('symbol')
        timeframe = request.args.get('timeframe', 'M1')
        start_str = request.args.get('start')
        end_str = request.args.get('end')
        
        if not all([symbol, start_str, end_str]):
            return jsonify({"error": "Symbol, start, and end parameters are required"}), 400

        # Map timeframe string to MT5 constant
        timeframe_map = {
            'M1': mt5.TIMEFRAME_M1,
            'M5': mt5.TIMEFRAME_M5,
            'M15': mt5.TIMEFRAME_M15,
            'M30': mt5.TIMEFRAME_M30,
            'H1': mt5.TIMEFRAME_H1,
            'H4': mt5.TIMEFRAME_H4,
            'D1': mt5.TIMEFRAME_D1,
            'W1': mt5.TIMEFRAME_W1,
            'MN1': mt5.TIMEFRAME_MN1
        }
        
        mt5_timeframe = timeframe_map.get(timeframe.upper())
        if mt5_timeframe is None:
            return jsonify({"error": f"Invalid timeframe: {timeframe}"}), 400

        # Convert string dates to datetime objects
        from datetime import datetime
        import pytz
        utc = pytz.UTC
        start_date = utc.localize(datetime.fromisoformat(start_str.replace('Z', '+00:00')))
        end_date = utc.localize(datetime.fromisoformat(end_str.replace('Z', '+00:00')))
        
        # Fetch data within range
        rates = mt5.copy_rates_range(symbol, mt5_timeframe, start_date, end_date)
        if rates is None:
            error_code, error_str = mt5.last_error()
            return jsonify({
                "error": "Failed to get rates data",
                "mt5_error": error_str,
                "error_code": error_code
            }), 404
        
        # Convert to list of dictionaries with ISO timestamps
        data_list = []
        for rate in rates:
            rate_dict = rate._asdict()
            if 'time' in rate_dict:
                rate_dict['time'] = datetime.fromtimestamp(
                    rate_dict['time'], tz=mt5.TIMEZONE
                ).isoformat()
            data_list.append(rate_dict)
        
        return jsonify(data_list), 200
    
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        logger.error(f"Error in fetch_data_range: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

---

## 10. Error Debugging Endpoints

### 10.1 Get Last Error

**Route**: `GET /last_error`

**Description**: Retrieve the last error code and message from MetaTrader5. Useful for debugging failed operations.

**Response Schema**:
```json
{
  "error_code": 10004,
  "error_message": "Requote"
}
```

**Implementation**:

**File**: `app/routes/error.py` (add to existing file or create new)

```python
@error_bp.route('/last_error', methods=['GET'])
@swag_from({
    'tags': ['Error'],
    'responses': {
        200: {
            'description': 'Last error retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'error_code': {'type': 'integer'},
                    'error_message': {'type': 'string'}
                }
            }
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def last_error_endpoint():
    """
    Get Last Error Code and Message
    ---
    description: Retrieve the last error code and message from MetaTrader5.
    """
    try:
        error_code, error_str = mt5.last_error()
        return jsonify({
            "error_code": error_code,
            "error_message": error_str
        }), 200
    except Exception as e:
        logger.error(f"Error in last_error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

### 10.2 Get Last Error String

**Route**: `GET /last_error_str`

**Description**: Retrieve only the last error message string from MetaTrader5.

**Response Schema**:
```json
{
  "error_message": "Requote"
}
```

**Implementation**:

**File**: `app/routes/error.py` (add to existing file)

```python
@error_bp.route('/last_error_str', methods=['GET'])
@swag_from({
    'tags': ['Error'],
    'responses': {
        200: {
            'description': 'Last error message retrieved successfully.',
            'schema': {
                'type': 'object',
                'properties': {
                    'error_message': {'type': 'string'}
                }
            }
        },
        500: {
            'description': 'Internal server error.'
        }
    }
})
def last_error_str_endpoint():
    """
    Get Last Error Message as String
    ---
    description: Retrieve the last error message string from MetaTrader5.
    """
    try:
        error_code, error_str = mt5.last_error()
        return jsonify({"error_message": error_str}), 200
    except Exception as e:
        logger.error(f"Error in last_error_str: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500
```

**Registration**: If creating new `app/routes/error.py`, add to `app/app.py`:
```python
from routes.error import error_bp
app.register_blueprint(error_bp)
```

---

## Implementation Checklist

### Phase 1: Core Missing Features (High Priority)
- [ ] **Account Information** (`GET /account_info`)
  - Create `app/routes/account.py`
  - Register blueprint in `app/app.py`
  - Add Swagger documentation
  - Test with real account

- [ ] **Cancel Order** (`POST /cancel_order`)
  - Add to `app/routes/order.py`
  - Add Swagger documentation
  - Test cancellation flow

- [ ] **Limit Orders** (Extend `/order` endpoint)
  - Update `send_market_order_endpoint` function
  - Add order type mapping
  - Handle pending order logic
  - Add expiration support
  - Update Swagger documentation
  - Test all order types

### Phase 2: Supporting Features (Medium Priority)
- [ ] **Symbol Selection** (`POST /symbol_select/{symbol}`)
  - Add to `app/routes/symbol.py`
  - Add Swagger documentation
  - Test symbol enable/disable

- [ ] **Terminal Information** (`GET /terminal_info`)
  - Add to `app/routes/health.py`
  - Add Swagger documentation
  - Test terminal status retrieval

### Phase 3: Enhanced Features (Nice to Have)
- [ ] **Get Pending Orders** (`GET /get_orders`)
  - Add to `app/routes/order.py`
  - Add magic number filtering
  - Add Swagger documentation
  - Test order retrieval

- [ ] **Position Count** (`GET /positions_total`)
  - Add to `app/routes/position.py`
  - Add Swagger documentation
  - Test position count retrieval

- [ ] **Enhanced History Endpoints**
  - `GET /get_deal_from_ticket` - Add to `app/routes/history.py`
  - `GET /get_order_from_ticket` - Add to `app/routes/history.py`
  - `GET /history_deals_get` - Add to `app/routes/history.py`
  - `GET /history_orders_get` - Add to `app/routes/history.py`
  - Add Swagger documentation for all
  - Test deal/order retrieval by ticket
  - Test history queries with date ranges

- [ ] **Enhanced Data Fetching**
  - `GET /fetch_data_pos` - Add to `app/routes/data.py`
  - `GET /fetch_data_range` - Add to `app/routes/data.py`
  - Add Swagger documentation
  - Test position-based data fetching
  - Test range-based data fetching

- [ ] **Error Debugging Endpoints**
  - `GET /last_error` - Add to `app/routes/error.py` (or create new file)
  - `GET /last_error_str` - Add to `app/routes/error.py`
  - Register error blueprint if new file created
  - Add Swagger documentation
  - Test error retrieval

---

## Testing Requirements

### Unit Tests
- Test each endpoint with valid inputs
- Test error handling (invalid inputs, MT5 errors)
- Test edge cases (empty results, connection failures)

### Integration Tests
- Test against real MT5 terminal
- Test order lifecycle (place limit order → cancel)
- Test account info retrieval
- Test symbol selection

### API Documentation
- Update Swagger/OpenAPI spec (`docs/apispec.json`)
- Ensure all new endpoints are documented
- Add request/response examples

---

## API Summary

### New Endpoints

| Method | Endpoint | Description | Priority |
|--------|----------|-------------|----------|
| GET | `/account_info` | Get account information | High |
| POST | `/cancel_order` | Cancel pending order | High |
| POST | `/order` | Place order (extended for limit/stop) | High |
| POST | `/symbol_select/{symbol}` | Select symbol in Market Watch | Medium |
| GET | `/terminal_info` | Get terminal information | Medium |
| GET | `/get_orders` | Get pending orders | Low |
| GET | `/positions_total` | Get total open positions count | Medium |
| GET | `/get_deal_from_ticket` | Get deal information by ticket | Medium |
| GET | `/get_order_from_ticket` | Get order information by ticket | Medium |
| GET | `/history_deals_get` | Get deals history with date range | Medium |
| GET | `/history_orders_get` | Get orders history | Medium |
| GET | `/fetch_data_pos` | Fetch historical data from position | Medium |
| GET | `/fetch_data_range` | Fetch historical data in date range | Medium |
| GET | `/last_error` | Get last MT5 error code and message | Low |
| GET | `/last_error_str` | Get last MT5 error message string | Low |

### Updated Endpoints

| Method | Endpoint | Changes |
|--------|----------|---------|
| POST | `/order` | Support limit/stop orders, expiration |

---

## Migration Notes

### For btrade Integration

1. **Account Info**: Replace direct `mt5.account_info()` calls with `GET /account_info`
2. **Cancel Order**: Replace `TRADE_ACTION_REMOVE` with `POST /cancel_order`
3. **Limit Orders**: Use extended `/order` endpoint with order type parameter
4. **Symbol Select**: Use `POST /symbol_select/{symbol}` before trading operations
5. **Terminal Info**: Use `GET /terminal_info` for connection verification
6. **Position Count**: Use `GET /positions_total` for quick position count checks
7. **Deal/Order History**: Use `GET /get_deal_from_ticket` and `GET /get_order_from_ticket` for ticket-based lookups
8. **History Queries**: Use `GET /history_deals_get` and `GET /history_orders_get` for filtered history
9. **Data Fetching**: Use `GET /fetch_data_pos` and `GET /fetch_data_range` for flexible historical data
10. **Error Debugging**: Use `GET /last_error` or `GET /last_error_str` for debugging failed operations

### Backward Compatibility

- Existing market order functionality remains unchanged
- All new features are additive (no breaking changes)
- Optional parameters maintain defaults

---

## Error Handling

All new endpoints should follow the existing error handling pattern:

```python
try:
    # MT5 operation
    result = mt5.some_function()
    if result is None:
        error_code, error_str = mt5.last_error()
        return jsonify({
            "error": "Operation failed",
            "mt5_error": error_str,
            "error_code": error_code
        }), 400
    return jsonify(result._asdict()), 200
except Exception as e:
    logger.error(f"Error: {str(e)}")
    return jsonify({"error": "Internal server error"}), 500
```

---

## Conclusion

All missing features can be implemented using standard MetaTrader5 Python library functions. The implementation follows the existing service patterns and should integrate seamlessly with the current codebase.

**Estimated Implementation Time**: 3-4 days for all features including testing and documentation.

**Dependencies**: None - all features use existing MT5 library functions.

**Risk Level**: Low - straightforward additions following established patterns.
