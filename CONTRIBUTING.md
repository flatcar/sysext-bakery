Welcome! We're so glad you're here and interested in contributing to Flatcar! 💖

Whether you're fixing a bug, adding a feature, or improving docs — we appreciate you!

For more detailed guidelines (finding issues, community meetings, PR lifecycle, commit message format, and more), check out the [main Flatcar CONTRIBUTING guide](https://github.com/flatcar/Flatcar/blob/main/CONTRIBUTING.md).

If you want to file an issue for any Flatcar repository, please use the [central Flatcar issue tracker](https://github.com/flatcar/Flatcar/issues).

---

## Repository Specific Guidelines

Any guidelines specific to this repository that are not covered in the main contribution guide will be listed here.

<!-- Add repo-specific guidelines below this line -->

### Test your extension before opening a pull request

Build the extension and validate the resulting image:

```sh
./bakery.sh create <extension> <version>
./bakery.sh test <extension>
```

`bakery.sh test` checks the image for the metadata, layout, and file ownership
`systemd-sysext` requires, for binaries built for the wrong architecture, and for systemd
units running commands that are not shipped. It exits non-zero if any check fails.

Please validate both architectures when you change how an extension is built:

```sh
./bakery.sh create <extension> <version> --arch arm64
./bakery.sh test <extension> --arch arm64
```

Pull requests that touch an extension - or the shared build and test code in `lib/` -
build and validate the affected extensions automatically for both architectures.

Extensions may also ship smoke tests in `<extension>.sysext/test.sh` that run on a booted
system with the extension merged. Implementing them is optional but appreciated:

```sh
./bakery.sh test <extension> --vm true
```

The hook contract is documented in [`_skel.sysext/test.sh`](_skel.sysext/test.sh).
Running these tests needs qemu and docker; they are not part of the pull request CI.