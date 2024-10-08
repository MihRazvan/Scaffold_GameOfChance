// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract ScaffoldETHDeploy is Script {
    error InvalidChain();
    error NoConfigFound();

    struct Deployment {
        string name;
        address addr;
    }

    struct Config {
        address priceFeed;
        address vrfCoordinator;
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 automationUpdateInterval;
        address link;
        address account;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2640e8;

    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    string root;
    string path;
    Deployment[] public deployments;

    Config config;

    function getConfig() public returns (Config memory) {
        if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            config = Config({
                subscriptionId: 60870646375565463954566831629343782343009001059421670546806704696565500871034,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                automationUpdateInterval: 30, // 30 seconds
                callbackGasLimit: 500000, // 500,000 gas
                account: 0x33A5608b3D641114f4d07576F2a6552baec9baA7,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
            return config;
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            return deployMockAndGetLocalConfig();
        } else {
            revert NoConfigFound();
        }
    }

    function deployMockAndGetLocalConfig() public returns (Config memory) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        VRFCoordinatorV2_5Mock mockVrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken link = new LinkToken();
        uint256 subscriptionId = mockVrfCoordinator.createSubscription();
        vm.stopBroadcast();

        // Add the mock price feed deployment to the deployments array
        deployments.push(
            Deployment({name: "MockV3Aggregator", addr: address(mockPriceFeed)})
        );
        deployments.push(
            Deployment({
                name: "MockVrfCoordinator",
                addr: address(mockVrfCoordinator)
            })
        );
        deployments.push(Deployment({name: "LinkToken", addr: address(link)}));

        config.priceFeed = address(mockPriceFeed);
        config.vrfCoordinator = address(mockVrfCoordinator);

        config = Config({
            subscriptionId: subscriptionId,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            automationUpdateInterval: 30, // 30 seconds
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinator: address(mockVrfCoordinator),
            priceFeed: address(mockPriceFeed),
            link: address(link),
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });
        vm.deal(config.account, 100 ether);
        return config;
    }

    /**
     * This function generates the file containing the contracts ABI definitions.
     * These definitions are used to derive the types needed in custom scaffold-eth hooks, for example.
     * This function should be called last.
     */
    function exportDeployments() internal {
        uint256 len = deployments.length;

        // Use 'deployments' as the object key
        for (uint256 i = 0; i < len; i++) {
            // Serialize each deployment under the 'deployments' object
            vm.serializeAddress(
                "deployments",
                deployments[i].name,
                deployments[i].addr
            );
        }

        // Construct the file path
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        string memory chainIdStr = vm.toString(block.chainid);
        path = string.concat(path, chainIdStr, ".json");

        // Write the JSON to the file using the object key directly
        vm.writeJson("deployments", path);
    }
}
