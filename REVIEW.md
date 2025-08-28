# Selecto Components Review

This document provides a review of the `selecto_components` library and its relationship with the `selecto` library.

## Findings

1.  **Outdated `selecto` Dependency:** `selecto_components` depends on `selecto` version `~> 0.2.6`. The `selecto` library has since been updated to version `0.3.0`, which includes a major security and validation overhaul. This means that `selecto_components` is not using the latest, most secure version of `selecto`.

2.  **Lack of Compatibility:** Due to the significant changes in `selecto` between versions `0.2.6` and `0.3.0`, `selecto_components` is not compatible with the latest version of `selecto`. The changes in `selecto` include a complete SQL parameterization refactor, which is a breaking change for `selecto_components`.

3.  **Potential Security Vulnerabilities:** By using an older version of `selecto`, `selecto_components` is potentially exposed to SQL injection vulnerabilities that have been fixed in the latest version of `selecto`.

4.  **No Longer Maintained:** The `selecto_components` library has not been updated to keep up with the changes in the `selecto` library, which suggests that it is no longer actively maintained.

## Recommendations

1.  **Update `selecto` Dependency:** The `selecto` dependency in `selecto_components` should be updated to `~> 0.3.0`. This will require significant changes to `selecto_components` to adapt to the new `selecto` API.

2.  **Adopt New `Selecto.Queryable` Behaviour:** The `Selecto.Queryable` behaviour has likely changed in `selecto` `v0.3.0`. The `selecto_components` library will need to be updated to use the new behaviour.

3.  **Replace Direct SQL String Construction:** The `selecto_components` library should be updated to use the new parameterized query functions in `selecto` to prevent SQL injection vulnerabilities.

4.  **Update `README.md`:** The `README.md` for `selecto_components` should be updated to reflect the changes in the library and to provide clear instructions on how to use the new version.

5.  **Consider Sunsetting `selecto_components`:** Given the significant amount of work required to update `selecto_components` and the fact that it appears to be unmaintained, it may be worth considering sunsetting the library and recommending that users build their own UI components using Phoenix LiveView and the latest version of `selecto`. This would allow users to take full advantage of the new features and security improvements in `selecto` and to build UIs that are tailored to their specific needs.

## Conclusion

The `selecto_components` library is a useful tool for quickly building a UI for the `selecto` query builder. However, it is outdated and potentially insecure. It is recommended that the library be updated to use the latest version of `selecto` or that it be sunsetted in favor of a more flexible and secure approach.
