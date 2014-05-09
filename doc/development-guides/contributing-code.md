## Contributing to OpenCrowbar

Before [submitting pull requests]
(https://help.github.com/articles/using-pull-requests), please ensure you are
covered by a [CLA](CLA.md).

#### Guidelines for Pull Requests

   * Must be Apache 2 license
   * For bugs & minor items (20ish lines), we can accept the request at our
     discretion
   * UI strings are localized (only EN file needs to be updated)
   * Does not inject vendor information (Name or Product) into OpenCrowbar expect
     where relevant to explain utility of push (e.g.: help documentation &
     descriptions).
   * Passes code review by Dell OpenCrowbar team reviewer
   * Does not degrade the security model of the product
   * Items requiring more scrutiny, including signing CLA
      * Major changes
      * New barclamps
      * New technology

#### Timing

   * Accept no non-bug fix push requests within 2 weeks of a release fork
   * No SLA - code accepted at Dell's discretion. No commitment to accept
     changes.

#### Coding Expectations [PRELIMINARY / PROPOSED 8/31]

   * Copyright & License header will be included in files that can tolerate
     headers
   * At least 1 line comments as header for all methods
   * Unit tests for all models concurrent with pull request
   * BDD tests for all API calls and web pages concurrent with pull request
   * Documentation for API calls concurrent with pull request
   * Adhere to the community [Ruby style guide]
     (https://github.com/bbatsov/ruby-style-guide)
   * Adhere to the community [Rails style guide]
     (https://github.com/bbatsov/rails-style-guide/)

#### Testing/ Validation

   * For core functions, push will be validated to NOT break build or deploy or
     our commercial products
   * For product suites (OpenStack, Hadoop, etc), push will be validated to NOT
     break build or deploy our commercial products
   * For operating systems that are non-core, we will _not_ validate on the
     target OS for the push (e.g.: not testing SUSE install at this point)
   * For non-DellCloudEdge barclamps &ndash; no rules!
   * Eventually, we would expect that a pull request would be built and tested
     in our CI system before the push can be accepted
'
#### Feature Progression

The following table shows the progression of new feature additions to OpenCrowbar.
The purpose of this list is to help articulate how new features appear in
OpenCrowbar and when they are considered core.

| Phase | Comments | Roadmap | Support | On Trunk |
|-----------|:-------------------------------------|:---------------------|:---------------|:-----------|
| Proposed | Conceptual ideas and suggestions for OpenCrowbar functionality that have not been implemented as code | May be shown | None | N/A |
| Proof of Concept | Initial code showing partial functionality for feature | Optionally Identified | Negative Test (Does not impact core) | No (on branch) |
| Incubated | Base functional code allowing use of feature to demonstrate value | Identified | Negative Test (Does not impact core) | No (on branch) |
| Stable | Base functional code is available for use in select builds | Included | Validated by QA, No Support | Yes|
| Core | Feature code integrated into operations of OpenCrowbar in fundamental way | Central | Validated by QA, Current Version Support | Yes |
| Supported | Same as core, but available with commercial support | Central | Backwards Support via Patches | Yes &amp; Maintained on Branches |

Note: Features are NOT required to progress through all these phases!
Architectural changes may skip ahead based on their level of impact and
disruption.
