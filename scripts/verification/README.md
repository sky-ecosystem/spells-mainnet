# Enhanced Contract Verification System

The `verify.py` script has been enhanced to provide robust retry mechanisms and support for multiple block explorers while maintaining the same simple interface.

## Overview

The verification system has been enhanced to address the following requirements:

1. **Multiple Block Explorer Support**: Verify contracts on at least 2 well-known block explorers
2. **Robust Retry Mechanisms**: Implement proper retry logic with exponential backoff and jitter
3. **Fallback Options**: If one verifier fails, automatically try others
4. **Backward Compatibility**: Maintain compatibility with existing Makefile commands

## Key Features

### **Retry Logic with Exponential Backoff**
```python
@retry_with_backoff(max_retries=3, base_delay=2, max_delay=60)
def api_request():
    # Automatic retry with exponential backoff + jitter
```

### **Multi-Verifier Support**
- **Etherscan**: Primary verifier with full API support
- **Sourcify**: Secondary verifier (no API key required)
- **Automatic Fallback**: If one fails, tries the next

### **Smart Error Handling**
- Graceful degradation when verifiers are unavailable
- Detailed logging of all attempts and failures
- Automatic retry for network issues and temporary failures

## Usage

### **Standard Usage (Unchanged)**
```bash
make verify addr=0x1234567890123456789012345678901234567890
```

### **Direct Script Usage**
```bash
./scripts/verify.py DssSpell 0x1234567890123456789012345678901234567890
```

## Configuration

### **Environment Variables**
- `ETHERSCAN_API_KEY`: Required for Etherscan verification
- `ETH_RPC_URL`: Required for chain operations

### **Retry Settings**
- **Max Retries**: 3 attempts
- **Base Delay**: 2 seconds  
- **Max Delay**: 60 seconds
- **Backoff Factor**: 2 (exponential)
- **Jitter**: 10% random variation to prevent thundering herd problems

## Supported Block Explorers

### Etherscan
- **Chains**: Mainnet (1), Sepolia (11155111)
- **API**: Etherscan API v2
- **Requirements**: API key
- **Features**: Full verification with constructor arguments and libraries

### Sourcify
- **Chains**: Mainnet (1), Sepolia (11155111)
- **API**: Sourcify API
- **Requirements**: No API key required
- **Features**: Open-source verification service

## Retry Mechanisms

### **Exponential Backoff with Jitter**

The system implements exponential backoff with jitter to prevent thundering herd problems:

```python
delay = min(base_delay * (backoff_factor ** attempt), max_delay)
jitter_amount = delay * jitter * random.uniform(-1, 1)
actual_delay = max(0, delay + jitter_amount)
```

### **Retry Scenarios**

1. **API Request Failures**: Network timeouts, HTTP errors, JSON parsing errors
2. **Contract Not Found**: Retry when contract is not yet deployed
3. **Verification Pending**: Poll for verification completion
4. **Subprocess Failures**: Forge flatten, cast commands

### **Error Handling**

- **Graceful Degradation**: If one verifier fails, others are still attempted
- **Detailed Logging**: All errors and retry attempts are logged
- **Fallback Strategy**: Try all available verifiers until one succeeds

## Benefits

1. **Reliability**: Multiple verifiers reduce single points of failure
2. **Resilience**: Retry mechanisms handle temporary network issues
3. **Transparency**: Detailed logging shows exactly what's happening
4. **Simplicity**: Single script with enhanced functionality
5. **Compatibility**: Existing workflows continue to work unchanged

## Testing

### **Running Tests**

The test suite uses relative imports and must be run as a module:

```bash
# ✅ Correct way - run as module
python3 -m scripts.verification.test_retry

# ❌ Incorrect way - direct execution fails
python3 scripts/verification/test_retry.py
```

**Why?** The test file uses relative imports (`from .retry import retry_with_backoff`) which only work when the file is run as part of a package, not as a standalone script.

### **Test Coverage**

The test suite covers:
- Successful retry scenarios
- Maximum retry limit handling
- Exponential backoff behavior
- Jitter variation
- Exception-specific retry logic
- Network simulation scenarios

## Troubleshooting

### **Common Issues**

1. **"No verifiers available"**: Check chain ID support and API keys
2. **"Verification failed on all verifiers"**: Check contract deployment and source code
3. **"Etherscan API key not found"**: Set `ETHERSCAN_API_KEY` environment variable
4. **"ImportError: attempted relative import with no known parent package"**: Run tests as a module using `python3 -m scripts.verification.test_retry`

### **Debug Mode**

For detailed debugging, you can run the script directly and observe the output:

```bash
./scripts/verify.py DssSpell 0x1234567890123456789012345678901234567890
```

### **Log Files**

Failed verifications create log files with the source code for debugging:

- `verify-etherscan-{timestamp}.log`

## Implementation Details

### **Verifier Classes**

The script includes two verifier classes:

- **`EtherscanVerifier`**: Handles Etherscan API verification
- **`SourcifyVerifier`**: Handles Sourcify API verification

Both classes implement the same interface and can be easily extended.

### **Retry Decorator**

The `@retry_with_backoff` decorator provides automatic retry functionality with:

- Configurable retry counts and delays
- Exponential backoff with jitter
- Exception filtering
- Detailed logging

### **Multi-Verifier Logic**

The script automatically:

1. Sets up all available verifiers for the current chain
2. Attempts verification with each verifier in sequence
3. Stops on first successful verification
4. Provides detailed feedback on all attempts

## Future Enhancements

1. **Configurable Retry**: Allow retry parameters via environment variables
2. **Parallel Verification**: Verify on multiple explorers simultaneously
3. **Verification Status**: Check if contract is already verified before attempting
4. **Custom Verifiers**: Allow custom verifier implementations

## Contributing

To add a new block explorer verifier:

1. Create a new verifier class following the existing pattern
2. Implement the required methods (`verify_contract`, `is_available`, etc.)
3. Add the verifier to the `setup_verifiers` function
4. Test with different chains and scenarios
