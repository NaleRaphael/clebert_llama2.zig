## llama2.zig

> Inference Llama 2 in pure Zig

This is a Zig port of [llama2.c](https://github.com/karpathy/llama2.c).

The current code is based on:
https://github.com/karpathy/llama2.c/blob/c7a26264a233c32f396b1c67be4ac019d2d8a659/run.c

I have significantly diverged from the original in terms of architecture and implementation.
However, my goal is to continue porting the improvements and new features of Andrej's C version into
this codebase. At present, my Zig port produces the same output as the C version. I ensure this
through the following linked [tests](./test.sh).

## TODOs

- Add support for chat (https://github.com/karpathy/llama2.c/pull/343)
- Use `errdefer` in all init methods (see generator)

## Usage

```sh
zig build -Doptimize=ReleaseFast run -- stories260K.bin -z tok512.bin -i "Once upon a time"
```

## Experimental Metal Support

Most of the time is spent on matrix multiplication. I am currently experimenting with speeding this
up using Metal. Currently, my Metal implementation is still much slower. The focus was initially on
getting it to perform the calculations correctly on the GPU.

```sh
./download-metal-cpp.sh
zig build -Dmetal=true run -- stories260K.bin -z tok512.bin -i "Once upon a time"
```

## Papers

- Standard transformer architecture: [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- Llama 1: [LLaMA: Open and Efficient Foundation Language Models](https://arxiv.org/abs/2302.13971)
- Llama 2: [Llama 2: Open Foundation and Fine-Tuned Chat Models](https://arxiv.org/abs/2307.09288)
- Pre-normalization using RMSNorm: [Root Mean Square Layer Normalization](https://arxiv.org/abs/1910.07467)
- SwiGLU activation function: [GLU Variants Improve Transformer](https://arxiv.org/abs/2002.05202)
- Rotary positional embeddings: [RoFormer: Enhanced Transformer with Rotary Position Embedding](https://arxiv.org/abs/2104.09864)
- Grouped-query attention: [GQA: Training Generalized Multi-Query Transformer Models from Multi-Head Checkpoints](https://arxiv.org/abs/2305.13245v1)
- Nucleus sampling: [The Curious Case of Neural Text Degeneration](https://arxiv.org/abs/1904.09751)
