const { spawn } = require('child_process');
require('dotenv').config(); // Initialize dotenv to load environment variables

(async() => {
    // Starting Anvil nodes for 'mainnet' and 'optimism'
    console.debug(`Starting Ganache node`);
    const ganachePromise = runGanacheNode();
    
    // Waiting for both nodes to be fully operational
    console.debug(`Waiting for node to be up and running...`);
    const ganache = await Promise.resolve(ganachePromise);

    // Running end-to-end tests
    console.debug(`Running tests`);
    const testProcess = spawn('yarn', [`test:e2e`]);

    // Handle test errors
    testProcess.stderr.on('data', (data) => console.error(`Test error: ${data}`));

    // Track the test result
    let testPassed = true;
    testProcess.stdout.on('data', (data) => {
        console.info(String(data));
        if (String(data).includes('Failing tests:')) testPassed = false;
    });

    // When tests are complete, kill the Ganache nodes
    testProcess.on('close', (code) => {
        console.debug(`Tests finished running, killing ganache node...`);
        try {
            ganache.kill();
            console.debug('Ganache nodes terminated successfully.');
        } catch (error) {
            console.error(`Error terminating Ganache nodes: ${error}`);
        }

        // Exit with an error code if tests failed
        if (!testPassed) {
            console.error('Tests failed. Setting exit code to 1.');
            process.exit(1);
        }
        
        // Exit with a success code if tests passed
        process.exit(0);
    });
})();


/**
 * Start an Anvil node for a given network
 * 
 * @param network: name of the network to run (string)
 * @returns promise which resolves when the node is running
 */
// function runAnvilNode(network) {
//     return new Promise((resolve, reject) => {
//         const node = spawn('yarn', [`anvil:${network}`]);

//         // Handle errors without exposing sensitive information
//         node.stderr.on('data', () => {
//             console.error(`Anvil ${network} node errored! Not showing the error log since it could reveal the RPC url.`);
//             reject();
//         });
        
//         // Resolve the promise when the node is up
//         node.stdout.on('data', (data) => {
//             if (String(data).includes('Listening on')) {
//                 console.debug(`Anvil ${network} node up and running`);
//                 resolve(node);
//             }
//         });
//     });
// }

/**
 * Start a Ganache node
 * 
 * @returns promise which resolves when the node is running
 */
function runGanacheNode() {
    return new Promise((resolve, reject) => {
        const node = spawn('yarn', ['ganache']);

        // Handle errors without exposing sensitive information
        node.stderr.on('data', () => {
            console.error(`Ganache node errored! Not showing the error log since it could reveal the RPC url.`);
            reject();
        });
        
        // Resolve the promise when the node is up
        node.stdout.on('data', (data) => {
            if (String(data).includes('Listening on')) {
                console.debug(`Ganache node up and running`);
                resolve(node);
            }
        });
    });
}