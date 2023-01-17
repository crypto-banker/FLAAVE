# FLAAVE - Flash Loaning Around AAVE Very Efficiently

## Table of Contents  
* [Introduction](#introduction)
* [Installation](#installation)
* [Usage](#usage)
* [Ethos](#ethos) 
* [Contributing To or Building On FLAAVE](#contributing)
* [Disclaimer](#disclaimer)


<a name="introduction"/></a>
## Introduction
FLAAVE is a "pure alpha" project.

Built for fun, it is designed to shift the Nash Equilibrium for participants in AAVE.

As a platform, FLAAVE brings together passive lenders on AAVE and anyone desiring cheap flash loans, in an easy-to-use, ERC-3156 compliant package.

FLAAVE is structured with a pool per aToken (interest-bearing token issued by AAVE). Lenders can deposit either aTokens themselves or the underlying asset of an aToken (which is in turn auto-converted into aTokens by the contract). By providing liquidity to FLAAVE, lenders can benefit from alpha over the interest rate paid by AAVE; LPs continue to accrue all interest paid by AAVE, while *also* earning additioanl flash loan fees.

Developers using FLAAVE for flash loans benefit from low fees and a minimalist, accessible interface. They can borrow up to the full liquidity of a FLAAVE pool – delivered in either aTokens or the underlying asset of an aToken – all in an ERC-3156 package.

<a name="installation"/></a>
## Installation
This repo uses [Foundry](https://book.getfoundry.sh/). Get it, then run:

`forge install`


<a name="tests"/></a>
## Tests
The tests file -- `/src/test/Tests.t.sol` provides multiple automated tests.

To run them:

`forge test -vv`


<a name="usage"/></a>
## Usage
Suppose `Lender` has


<a name="ethos"/></a>
## Ethos
FLAAVE was built for fun. It is AGPL-licensed](https://www.gnu.org/licenses/agpl-3.0.en.html) due to importing AAVE's AGPL-licensed interface contracts; however, if you'd like to use any of the original work in this repo -- for any purposes -- go ahead!

FLAAVE is flexibly implemented to be deployable with an upgradeable proxy architecture, *or* as non-upgradeable. This is primarily because AAVE's contracts are themselves upgradeable proxies, meaning it is *possible* for AAVE to upgrade in a manner that makes its contracts incompatible with FLAAVE, forcing FLAAVE to upgrade. However, since the chance of this is rather low, users may be more comfortable with a non-upgradeable FLAAVE.


<a name="contributing"/></a>
## Contributing To or Building On FLAAVE
FLAAVE is an open source project built with love! :heart:

If you'd like to contribute, feel free to open a PR. If you're adding more features, please document your changes.

If you have questions or you'd like to discuss FLAAVE, you can contact @TokenPhysicist on Twitter.


<a name="disclaimer"/></a>
## Disclaimer
THIS SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THIS SOFTWARE OR THE USE OR OTHER DEALINGS IN THIS SOFTWARE.