# barcode-reader

A barcode reader written in x86/x64 assembly for CODE-39.

## Building

```console
make <TARGET>
```

Where target is one of the following:

| TARGET  | DESCRIPTION                          |
|---------|--------------------------------------|
| **x64** | (default) builds a 64 bit executable |
| **x86** | builds a 32 bit executable           |

## Running

```console
proj64 <image>
```

## Supported formats

Only uncompressed bitmap files are supported. Image has to be exactly 600x50px,
no distortions, black and white only. Barcode must be parallel to the vertical
image edge, and must intersect the middle of the image. Bars need to follow all
CODE-39 specifications.

