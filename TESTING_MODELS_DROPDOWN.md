# Testing the Models Dropdown Fix

## Issue
The model dropdown on the Launch Server page was not finding any downloaded models.

## Root Cause
The server's default models directory (`/home/jon/git/llama-server/models`) was different from where the launch script saves models (`~/.local/llama-cpp/models`).

## Fix Applied
Changed the server to use the same default models directory as the launch script: `~/.local/llama-cpp/models`

## How to Test

### Option 1: Download a Real Model
1. Start the development server:
   ```bash
   cd /home/jon/git/llama-server
   npm start
   ```

2. Open the web UI in your browser (usually `http://localhost:8080`)

3. Navigate to the **Models** page from the sidebar

4. Search for and download a small model (e.g., search for "Qwen2.5-0.5B" or "TinyLlama")

5. Once downloaded, go to the **Scripts** page and select **Launch Server**

6. The model dropdown should now show your downloaded model

### Option 2: Test with the Demo Model File
A test model file has been created at `~/.local/llama-cpp/models/test-model-Q4_K_M.gguf`

1. Start the development server:
   ```bash
   cd /home/jon/git/llama-server
   npm start
   ```

2. Open `http://localhost:8080` in your browser

3. Navigate to **Scripts** → **Launch Server**

4. The model dropdown should show "test-model-Q4_K_M.gguf"

### Option 3: Verify API Directly
Test the API endpoint directly:

```bash
curl http://localhost:8080/api/models | python3 -m json.tool
```

Expected output:
```json
{
  "models": [
    {
      "filename": "test-model-Q4_K_M.gguf",
      "size": 104857600,
      "path": "/home/jon/.local/llama-cpp/models/test-model-Q4_K_M.gguf",
      "mtimeMs": 1771678281774.9888
    }
  ],
  "modelsDir": "/home/jon/.local/llama-cpp/models"
}
```

## Troubleshooting

### Browser Cache
If you don't see the changes, try:
1. Hard refresh the page (Ctrl+Shift+R or Cmd+Shift+R)
2. Clear browser cache
3. Open in incognito/private mode

### Models Directory
Verify the models directory exists and contains models:
```bash
ls -lh ~/.local/llama-cpp/models/
```

### Server Not Running
Make sure the development server is actually running:
```bash
lsof -i :8080
```

If nothing is running on port 8080, start the server:
```bash
cd /home/jon/git/llama-server
npm start
```

## Expected Behavior After Fix

1. **Models Page**: Shows the models directory path (`~/.local/llama-cpp/models`) under "Local Models"

2. **Launch Server Page**: The model dropdown now:
   - Shows all `.gguf` files from `~/.local/llama-cpp/models`
   - Displays a helpful message when empty, explaining where to download models
   - Shows the directory path in the help text

3. **Model Downloads**: All models downloaded via:
   - The Models page
   - The `--hf` flag in Launch Server

   ...will be saved to the same directory and appear in the dropdown

## Clean Up Test Model
To remove the test model file:
```bash
rm ~/.local/llama-cpp/models/test-model-Q4_K_M.gguf
```
