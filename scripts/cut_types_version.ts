
import { parse, stringify } from 'yaml';
import { join } from 'path';
import { readFileSync, promises } from 'fs';

import { execSync } from 'child_process';

const typesPubspec = join('goals_types', 'pubspec.yaml');
const versionFile = join('goals_types', 'lib', 'src', 'version.dart');

const contents = readFileSync(typesPubspec, 'utf8');

const pubspec = parse(contents);

const newPeggedVersion = pubspec.version;
const peggedMajorVersion = newPeggedVersion.split('.')[0];

const new_package_name = `goals_types_${peggedMajorVersion}`;

async function updatePubspec(newPubspec: any) {
   await promises.writeFile(typesPubspec, stringify(newPubspec));
}

async function publishPeggedVersion() {
    // cut branch
    execSync(`git checkout -b ${new_package_name}`);

    // modify pubspec.yaml
    pubspec.name = new_package_name;
    
    updatePubspec(pubspec);

    // commit
    execSync(`git commit -am "cut ${new_package_name}"`);

    // push
    execSync(`git push`);

    // run pub publish
    execSync(`fvm dart pub publish`);

    execSync(`git checkout -`);
}

async function updateCurrentCode() {
    // modify pubspec.yaml
    pubspec.name = 'goals_types';
    pubspec.version = `${peggedMajorVersion+1}.0.0`;
    for (const dep of Object.keys(pubspec.dependencies)) {
        if (dep.startsWith("goals_types_")) {
            delete pubspec.dependencies[dep];
        }
    }

    pubspec.dependencies[new_package_name] = newPeggedVersion;
    
    updatePubspec(pubspec);

    await promises.writeFile(versionFile, stringify(newPubspec));

    // commit
    execSync(`git commit -am "consume ${new_package_name}"`);

    // push
    execSync(`git push`);
}


async function main() {
    await publishPeggedVersion();
    await updateCurrentCode();
}

main().catch(console.error);