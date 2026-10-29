/* Read-only catalogue of dependency declarations and the two checked-in pin graphs. */
import fs from 'node:fs/promises';
import path from 'node:path';
const canonical = value => value.toLowerCase().replace(/\.git\/?$/, '').replace(/\/$/, '');
const roles = {
  alamofire: ['Networking', 'HTTP networking; inspect approved dispatchers, interception and authentication before calling it directly.'],
  'apollo-ios': ['Networking', 'GraphQL client/runtime; generated operation and schema ownership still need verification.'],
  'auth0.swift': ['Authentication', 'Authentication SDK integration; system session, credentials and callback handling remain app responsibilities.'],
  'jwtdecode.swift': ['Authentication', 'JWT decoding support; decoding claims does not by itself verify a token signature or authorize an action.'],
  simplekeychain: ['Authentication', 'Keychain convenience APIs; accessibility, account ownership and logout policy remain explicit.'],
  'braze-swift-sdk': ['Integration', 'Messaging/engagement SDK; callbacks, consent, permissions and lifecycle are separate contracts.'],
  'ios-branch-sdk-spm': ['Integration', 'Linking/attribution integration; inbound URLs still require trusted routing and validation.'],
  'twilio-video-ios': ['Media', 'Video-call SDK; permission, audio-route, interruption and degraded-network behavior need specialized validation.'],
  'datadome-ios-package': ['Integration', 'Bot-protection SDK; inspect the current composition and request interception boundary.'],
  'datadome-alamofire-package': ['Integration', 'Adapter between bot-protection behavior and Alamofire request processing.'],
  'ios-aws-frameworks': ['Integration', 'Company-packaged AWS framework dependency; inspect the wrapper and linked products rather than assuming every AWS API is used.'],
  'ios-event-schemas': ['Observability', 'Company event schemas; event names and schema types do not establish privacy-safe payload behavior.'],
  'sentry-cocoa': ['Observability', 'Crash/error diagnostics SDK; matching symbols, privacy and reporting configuration still matter.'],
  'opentelemetry-swift': ['Observability', 'Telemetry APIs/SDK; span ownership, context propagation, exporters and data minimization need inspection.'],
  'opentracing-objc': ['Observability', 'Objective-C tracing interfaces supporting integrations; a pin does not prove active runtime spans.'],
  thrift: ['Supporting dependency', 'Thrift serialization/RPC support; verify generated types and actual consumers.'],
  'thrift-swift': ['Supporting dependency', 'Thrift serialization/RPC support; verify generated types and actual consumers.'],
  promisekit: ['Reactive / legacy', 'Promise-based asynchronous composition; the checkout guidance prefers migration toward native concurrency.'],
  reactivekit: ['Reactive / legacy', 'Reactive observation/stream support; audit lifetime and event semantics instead of assuming Flow parity.'],
  snapkit: ['UI', 'Auto Layout DSL; UIKit constraint priorities and sizing behavior remain the underlying contract.'],
  sdwebimage: ['UI', 'Image loading/caching; verify decode dimensions, cell reuse and cache budgets in actual consumers.'],
  'lottie-spm': ['UI', 'Animation runtime; rendering cost, reduced motion and resource inclusion still need testing.'],
  peasy: ['UI', 'Layout helper dependency in the legacy graph; inspect its actual call sites before selecting it for new code.'],
  swinject: ['Composition', 'Dependency-container library; the production ZDModules convention must not be inferred from demo dependencies.'],
  'swift-snapshot-testing': ['Testing', 'Snapshot-testing support; reviewed pixels do not replace behavioral or accessibility evidence.'],
  'xctest-dynamic-overlay': ['Testing', 'Testing-related support dependency; inspect the consuming package and effect outside test execution.'],
  'swift-custom-dump': ['Testing', 'Readable value comparison/dump support used by test and diagnostic integrations.'],
  'swift-syntax': ['Developer tooling', 'Swift syntax/macro tooling; compiler compatibility and plugin loading are distinct from app OS availability.'],
  'swift-argument-parser': ['Developer tooling', 'Command-line argument parsing; a workspace pin does not mean the library ships in every app target.'],
  swiftformat: ['Developer tooling', 'Swift formatting tooling; distinguish repository tools from linked runtime code.'],
  swiftlintplugins: ['Developer tooling', 'Lint/build-plugin integration visible in the legacy graph; verify actual enabled plugin use.'],
  'code-connect': ['Developer tooling', 'Design/code connection tooling; distinguish design integration from app runtime dependencies.'],
  'swift-collections': ['Language / data', 'Additional collection types; choose structures according to algorithm and workload evidence.'],
  'swift-algorithms': ['Language / data', 'Sequence/collection algorithms; semantics and intermediate allocation costs still need review.'],
  'swift-async-algorithms': ['Concurrency', 'Async-sequence operators; inspect buffering, termination and availability semantics.'],
  'swift-atomics': ['Concurrency', 'Atomic primitives; individual atomic operations do not establish a complete concurrent invariant.'],
  'swift-numerics': ['Language / data', 'Numerical types and operations; domain precision and format choices remain explicit.'],
  'swift-system': ['Supporting dependency', 'System-level APIs supporting dependency implementations; inspect platform and module requirements.'],
  'swift-log': ['Observability', 'Logging APIs; metadata and payload redaction remain the caller and backend policy.'],
  'swift-metrics': ['Observability', 'Metrics interfaces; useful signals require defined units, labels, denominators and privacy bounds.'],
  'swift-protobuf': ['Networking', 'Protocol Buffers generated/runtime support; wire compatibility and schema ownership still matter.'],
  'grpc-swift': ['Networking', 'gRPC support; the resolved graph does not prove a feature invokes this transport directly.'],
  'swift-nio': ['Networking', 'Event-driven networking foundations used by dependency implementations; not a replacement for app task-lifetime policy.'],
  'swift-nio-extras': ['Networking', 'Additional SwiftNIO components; inspect the importing products in the resolved graph.'],
  'swift-nio-http2': ['Networking', 'HTTP/2 support for SwiftNIO integrations.'],
  'swift-nio-ssl': ['Networking', 'TLS support for SwiftNIO integrations; trust/authentication policy is not inferred from a pin.'],
  'swift-nio-transport-services': ['Networking', 'Apple transport-services integration for SwiftNIO consumers.'],
  'swift-http-types': ['Networking', 'HTTP value types shared by library implementations.'],
  'swift-http-structured-headers': ['Networking', 'HTTP structured-field support; inspect the consumers and wire contract.'],
  'swift-service-lifecycle': ['Concurrency', 'Service-lifetime coordination used by integrations; app/scene lifetime remains an explicit owner.'],
  'swift-crypto': ['Security support', 'Cryptographic implementation/APIs supporting libraries; security needs a threat model and verified protocol usage.'],
  'swift-asn1': ['Security support', 'ASN.1 encoding/decoding support used by cryptographic and certificate dependencies.'],
  'swift-certificates': ['Security support', 'Certificate representation/validation support; a pin does not prove an app-specific trust policy.']
};
export async function buildCatalogue(workspace) {
  const declarationPath = 'ios-client/Tuist/Package.swift';
  const declarations = await fs.readFile(path.join(workspace, declarationPath), 'utf8');
  const requirements = new Map();
  for (const match of declarations.matchAll(/\.package\(\s*url:\s*"([^"]+)"\s*,\s*(exact|from|branch):\s*"([^"]+)"\s*\)/g)) {
    requirements.set(canonical(match[1]), { kind: match[2], value: match[3], path: declarationPath, line: declarations.slice(0, match.index).split('\n').length });
  }
  const graphs = [
    { name: 'Tuist', path: 'ios-client/Tuist/Package.resolved' },
    { name: 'Legacy workspace', path: 'ios-client/Zocdoc.xcworkspace/xcshareddata/swiftpm/Package.resolved' }
  ];
  const packages = new Map();
  for (const graph of graphs) {
    const source = await fs.readFile(path.join(workspace, graph.path), 'utf8');
    const content = JSON.parse(source);
    if (!Array.isArray(content.pins)) throw new Error(`Unsupported pin format: ${graph.path}`);
    for (const pin of content.pins) {
      if (!/^[a-z0-9.-]+$/.test(pin.identity) || !/^https:\/\//.test(pin.location) || !pin.state?.revision) throw new Error(`Invalid dependency pin ${pin.identity}`);
      const requirement = requirements.get(canonical(pin.location));
      const [category, purpose] = roles[pin.identity] || ['Supporting dependency', 'Resolved dependency; inspect its package documentation and consuming targets before assigning a responsibility.'];
      let item = packages.get(pin.identity);
      if (!item) {
        item = { id: pin.identity, category, purpose, url: pin.location, requirement: requirement || null, graphs: [], lesson: '045' };
        packages.set(pin.identity, item);
      }
      const line = source.split('\n').findIndex(value => value.includes('"identity"') && value.includes(`"${pin.identity}"`)) + 1;
      if (!line) throw new Error(`Missing dependency anchor ${pin.identity}`);
      item.graphs.push({ name: graph.name, path: graph.path, line, version: pin.state.version || null, branch: pin.state.branch || null, revision: pin.state.revision });
    }
  }
  for (const [url] of requirements) if (![...packages.values()].some(item => canonical(item.url) === url)) throw new Error(`Declared dependency has no checked-in pin: ${url}`);
  return {
    auditedAt: '2026-10-27',
    scope: 'A read-only inventory of remote pins in the Tuist and legacy workspace graphs, plus direct remote declarations in Tuist/Package.swift. This is not an exhaustive inventory of vendored/local frameworks, system frameworks, package-level requirements, or proven runtime consumers. Session 045 explains the broader landscape.',
    sources: [{ path: declarationPath, line: 49 }, ...graphs.map(graph => ({ path: graph.path, line: 1 }))],
    packages: [...packages.values()].sort((a, b) => a.id.localeCompare(b.id))
  };
}
