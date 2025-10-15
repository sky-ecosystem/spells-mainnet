#!/usr/bin/env python3
"""
Retry decorator with exponential backoff and jitter for robust API calls.
"""
import time
import random
import sys
from typing import Tuple, Callable
from functools import wraps


# Default retry configuration
DEFAULT_MAX_RETRIES = 3
DEFAULT_BASE_DELAY = 2  # seconds
DEFAULT_MAX_DELAY = 60  # seconds
DEFAULT_BACKOFF_FACTOR = 2
DEFAULT_JITTER = 0.1  # 10% jitter


def retry_with_backoff(
    max_retries: int = DEFAULT_MAX_RETRIES,
    base_delay: float = DEFAULT_BASE_DELAY,
    max_delay: float = DEFAULT_MAX_DELAY,
    backoff_factor: float = DEFAULT_BACKOFF_FACTOR,
    jitter: float = DEFAULT_JITTER,
    exceptions: Tuple[Exception, ...] = (Exception,)
):
    """
    Decorator that implements exponential backoff with jitter for retrying functions.
    
    Args:
        max_retries: Maximum number of retry attempts
        base_delay: Initial delay between retries in seconds
        max_delay: Maximum delay between retries in seconds
        backoff_factor: Multiplier for exponential backoff
        jitter: Random variation factor (0.1 = 10% variation)
        exceptions: Tuple of exceptions to catch and retry on
    
    Returns:
        Decorated function with retry logic
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    
                    if attempt == max_retries:
                        print(f"Failed after {max_retries + 1} attempts. Last error: {str(e)}", file=sys.stderr)
                        raise
                    
                    # Calculate delay with exponential backoff and jitter
                    delay = min(base_delay * (backoff_factor ** attempt), max_delay)
                    jitter_amount = delay * jitter * random.uniform(-1, 1)
                    actual_delay = max(0, delay + jitter_amount)
                    
                    print(f"Attempt {attempt + 1} failed: {str(e)}", file=sys.stderr)
                    print(f"Retrying in {actual_delay:.2f} seconds... (attempt {attempt + 2}/{max_retries + 1})", file=sys.stderr)
                    
                    time.sleep(actual_delay)
            
            raise last_exception
        return wrapper
    return decorator
