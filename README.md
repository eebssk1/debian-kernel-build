This repo builds manual tuned/modified linux kernel using xanmod base.

Both gcc and llvm builds are provided, but llvm builds may not stable.

**To support LTO, kernel configs are initialized with LLVM.**

Variant description:
- `bro-d` desktop kernel with broadwell base(depracated, not really used by me yet).
- `bro-sl` baremetal, server and other large machines kernel with broadwell base. With Nvidia OGPU module inbuilt.
- `bro-sl-plain` same as `bro-sl` but with default nouveau driver.
- `bro-sm` legacy small machines, VMs, Cloud like kernel with broadwell base.
- `ivy-sm` same as `bro-sm` but with ivybridge base.
- `ze2-sm` same as `bro-sm` but with amd zen2 base.
- `gen-sm` same as `bro-sm` but with almost generic base.

All build entry from `b.sh`
The deb targets to debian 13 on mind,but may be able to install on older distro.