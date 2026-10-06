MAC2IOS=/nix/store/0h5lyyscvlngxbp24d1sw5f92a2by7sk-mac2ios/bin/mac2ios
for f in apps/ios/Libraries/sim/*.a; do
    echo "Processing: $f"
    $MAC2IOS -s "$f"
done
echo "All simulator libs patched!"

