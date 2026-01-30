#!/bin/bash
# 压缩大视频文件以便网络播放

VIDEO_DIR="/Users/nemo.liu/code/robotransfer_homepage/static/videos"
MAX_SIZE_MB=10

echo "检查视频文件大小..."
echo "最大文件大小限制: ${MAX_SIZE_MB}MB"
echo ""

# 查找所有mp4文件并检查大小
find "$VIDEO_DIR" -name "*.mp4" -type f | while read video; do
    size_mb=$(du -m "$video" | cut -f1)
    filename=$(basename "$video")
    
    if [ "$size_mb" -gt "$MAX_SIZE_MB" ]; then
        echo "⚠ $filename: ${size_mb}MB (需要压缩)"
        
        # 创建压缩版本
        dir=$(dirname "$video")
        base=$(basename "$video" .mp4)
        compressed="${dir}/${base}_compressed.mp4"
        backup="${dir}/${base}_original.mp4"
        
        echo "  正在压缩..."
        ffmpeg -i "$video" \
            -c:v libx264 \
            -preset medium \
            -b:v 2000k \
            -maxrate 2000k \
            -bufsize 4000k \
            -c:a aac \
            -b:a 128k \
            -movflags +faststart \
            -y "$compressed" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            new_size=$(du -m "$compressed" | cut -f1)
            echo "  ✓ 压缩完成: ${new_size}MB"
            
            # 备份原文件并替换
            mv "$video" "$backup"
            mv "$compressed" "$video"
            echo "  原文件已备份为: ${base}_original.mp4"
        else
            echo "  ✗ 压缩失败"
            rm -f "$compressed"
        fi
        echo ""
    else
        echo "✓ $filename: ${size_mb}MB (无需压缩)"
    fi
done

echo "完成！"
