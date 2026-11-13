curl -G \
    --url-query "+info_hash=%CB%40%AC%7B%29%8F%00%0B%2C%6A%E0%8E%BC%31%9D%88%A0%FC%91%E9" \
    --url-query "peer_id=-nT2137-123456789012" \
    --url-query "port=49152" \
    --url-query "left=1048576" \
    --url-query "compact=1" \
    --output content \
    http://tracker.opentrackr.org:1337/announce
