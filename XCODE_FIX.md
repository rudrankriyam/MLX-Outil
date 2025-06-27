# Fix Xcode Build Issues

To fix the current build issues:

1. **Re-add MLX Swift Examples dependencies**:
   - Open MLX Outil.xcodeproj in Xcode
   - Select the project in the navigator
   - Go to the "Package Dependencies" tab
   - You should see mlx-swift-examples is already there
   - Select the "MLX Outil" target
   - Go to "General" tab → "Frameworks, Libraries, and Embedded Content"
   - Click "+" and add:
     - MLXLLM
     - MLXLMCommon

2. **Clean and rebuild**:
   - Product → Clean Build Folder (⇧⌘K)
   - Product → Build (⌘B)

The issue is that when we added MLXTools, the MLXLLM and MLXLMCommon dependencies were accidentally removed from the target's frameworks list. They need to be re-added since LLMManager still uses them directly.