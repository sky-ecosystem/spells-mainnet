#!/usr/bin/env python3
"""
Test suite for the retry mechanism with exponential backoff and jitter.
"""
import time
import random
import unittest
from unittest.mock import patch, MagicMock
from typing import Tuple, Callable

from retry import retry_with_backoff, DEFAULT_MAX_RETRIES, DEFAULT_BASE_DELAY


class TestRetryMechanism(unittest.TestCase):
    """Test cases for the retry mechanism."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.call_count = 0
    
    def test_successful_retry(self):
        """Test that retry mechanism works when function eventually succeeds."""
        @retry_with_backoff(max_retries=3, base_delay=0.1)
        def test_function():
            self.call_count += 1
            if self.call_count < 3:
                raise Exception(f"Simulated failure #{self.call_count}")
            return "Success!"
        
        result = test_function()
        self.assertEqual(result, "Success!")
        self.assertEqual(self.call_count, 3)
    
    def test_max_retries_exceeded(self):
        """Test that retry mechanism fails after max retries."""
        @retry_with_backoff(max_retries=2, base_delay=0.1)
        def test_function():
            self.call_count += 1
            raise Exception(f"Persistent failure #{self.call_count}")
        
        with self.assertRaises(Exception) as context:
            test_function()
        
        self.assertIn("Persistent failure #3", str(context.exception))
        self.assertEqual(self.call_count, 3)  # 2 retries + 1 initial attempt
    
    def test_no_retry_on_success(self):
        """Test that successful function doesn't retry."""
        @retry_with_backoff(max_retries=3, base_delay=0.1)
        def test_function():
            self.call_count += 1
            return "Success!"
        
        result = test_function()
        self.assertEqual(result, "Success!")
        self.assertEqual(self.call_count, 1)  # Only one call, no retries
    
    def test_exponential_backoff(self):
        """Test that delays increase exponentially."""
        delays = []
        
        @retry_with_backoff(max_retries=3, base_delay=1, max_delay=10)
        def test_function():
            delays.append(time.time())
            raise Exception("Test failure")
        
        start_time = time.time()
        with self.assertRaises(Exception):
            test_function()
        
        # Check that delays are increasing (with some tolerance for jitter)
        if len(delays) >= 3:
            delay1 = delays[1] - delays[0]
            delay2 = delays[2] - delays[1]
            self.assertGreater(delay2, delay1 * 1.5)  # Should be roughly 2x with jitter
    
    def test_jitter_variation(self):
        """Test that jitter adds random variation to delays."""
        delays = []
        
        @retry_with_backoff(max_retries=2, base_delay=1, jitter=0.2)
        def test_function():
            delays.append(time.time())
            raise Exception("Test failure")
        
        with self.assertRaises(Exception):
            test_function()
        
        # With jitter, delays should not be exactly the same
        if len(delays) >= 2:
            delay1 = delays[1] - delays[0]
            delay2 = delays[2] - delays[1]
            # Delays should be different due to jitter
            self.assertNotEqual(delay1, delay2)
    
    @patch('time.sleep')
    def test_specific_exception_handling(self, mock_sleep):
        """Test that only specified exceptions trigger retries."""
        @retry_with_backoff(max_retries=2, base_delay=0.1, exceptions=(ValueError,))
        def test_function():
            self.call_count += 1
            if self.call_count == 1:
                raise ValueError("Value error")
            elif self.call_count == 2:
                raise TypeError("Type error")  # Should not retry
            return "Success!"
        
        with self.assertRaises(TypeError):
            test_function()
        
        # Should only retry once (for ValueError), then fail on TypeError
        self.assertEqual(self.call_count, 2)
        mock_sleep.assert_called_once()  # Only one retry attempt


class TestRetryIntegration(unittest.TestCase):
    """Integration tests for the retry mechanism."""
    
    def test_retry_with_network_simulation(self):
        """Test retry mechanism with simulated network failures."""
        failures = [True, True, False]  # Fail twice, succeed on third attempt
        
        @retry_with_backoff(max_retries=3, base_delay=0.1)
        def simulate_network_call():
            if failures.pop(0):
                raise ConnectionError("Network timeout")
            return "Network response"
        
        result = simulate_network_call()
        self.assertEqual(result, "Network response")
        self.assertEqual(len(failures), 0)  # All failures consumed
    
    def test_retry_with_different_exception_types(self):
        """Test retry mechanism with different types of exceptions."""
        exceptions = [ValueError("Bad value"), ConnectionError("Network error"), "Success"]
        
        @retry_with_backoff(max_retries=3, base_delay=0.1, exceptions=(ValueError, ConnectionError))
        def test_function():
            exception = exceptions.pop(0)
            if isinstance(exception, Exception):
                raise exception
            return exception
        
        result = test_function()
        self.assertEqual(result, "Success")
        self.assertEqual(len(exceptions), 0)


if __name__ == "__main__":
    # Run the tests
    unittest.main(verbosity=2)
