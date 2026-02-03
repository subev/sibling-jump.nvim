# Test fixture for Python statement navigation

def process_data(items, config):
    # Simple assignments
    total = 0
    count = len(items)
    
    # Tuple unpacking
    name, version = config.get_info()
    x, y, z = calculate_coordinates(items[0])
    
    # For loop
    for item in items:
        value = item.process()
        total += value
    
    # If-elif-else chain
    if total > 100:
        status = "high"
    elif total > 50:
        status = "medium"
    else:
        status = "low"
    
    # Dict literal
    result = {
        "total": total,
        "count": count,
        "status": status,
    }
    
    return result


def another_function():
    pass


def error_handling():
    before = 1
    
    try:
        risky_operation()
    except ValueError:
        handle_value_error()
    except TypeError as e:
        handle_type_error(e)
    finally:
        cleanup()
    
    after = 2


def context_manager():
    before = 1
    
    with open('file.txt') as f:
        content = f.read()
    
    after = 2
