---
title: "An Architectural Lesson from Open vSwitch"
description: A look at declarative configuration, database-driven controllers, and the challenges of separating intent from execution.
date: 2026-10-26T07:33:58Z
draft: false
tags: ['software-architecture', 'openvswitch']
---

One thing I've enjoyed throughout my software engineering journey is seeing how
different developers approach the same kind of problem. There are many
interesting ideas in software design, and some of the ones I've admired most
come from the contributors to **Open vSwitch (OVS)**.

OVS is widely used as a virtual switching platform, including in infrastructure
built around OpenStack. What I find particularly interesting isn't just what it
can do, but how it manages to provide a relatively simple configuration
interface while handling a great deal of complexity underneath.

I'm certainly not an OVS expert, but there's one architectural decision that has
caught my attention for a while is the separation of the **configuration database**
from the daemon responsible for **applying that configuration**.

This decision is closely related to the difference between *imperative* and
*declarative* design. Before getting into OVS, it's worth briefly looking at
that distinction. The goal here isn't to explore OVS internals, but to
understand an approach that we might find useful in our own projects.

> **Note:** Some configuration snippets and operations in this post are
> simplified examples to illustrate the ideas. They are not necessarily actual
> OVS commands or OVSDB syntax.

## Imperative vs. Declarative Configuration

Imagine we're building a service to manage network bridges, interfaces, and their configuration.

One approach would be to expose operations like these:

```text
create_bridge("br0")
add_port("br0", "eth1")
set_mtu("eth1", 1400)
```

The caller tells the service **what operations to perform**, and the service attempts to execute
them. This is an *imperative* interface: we're specifying the steps that should happen.

There's nothing inherently wrong with this. It's a familiar approach, and it can be a good choice
for small and large systems alike. The operations are explicit, their results can often be returned
directly, and the implementation may be easier to reason about. An imperative interface also doesn't
prevent a system from having persistence, retries, or recovery mechanisms.

Now consider a different interface. Instead of sending a sequence of operations, we describe what we
want the resulting network to look like:

```yaml
bridges:
  - name: br0
    ports:
      - eth1
    mtu: 1400
```

Here, we're describing the **desired state**, not the steps needed to achieve it. Some other
component must interpret this description and perform the necessary operations. This is a
*declarative* approach.

The distinction is about the **interface and responsibility**, not whether one approach is modern or
universally better. Imperative systems can be reliable and sophisticated; declarative systems still
need imperative code somewhere to get the work done.

If you've worked with **Kubernetes**, this way of thinking should sound familiar. For example,
specifying `replicas: 3` in a Deployment describes the number of replicas we want. We don't normally
manage the individual steps of starting replacements whenever a Pod disappears; Kubernetes
controllers work toward the declared target.

Of course, the details are much more involved, and declarative configuration probably deserves a
separate article of its own. For now, what's important is the idea of expressing a target rather
than issuing every operation ourselves.

OVS gives us an interesting example of how such an interface can be implemented.

## Separating Configuration from Execution

In OVS, two components are particularly relevant to our discussion:

- **`ovsdb-server`** maintains the database containing the desired configuration of bridges,
  ports, interfaces, and other settings, along with certain operational information reported 
  by the switch.
- **`ovs-vswitchd`** observes the configuration and reconfigures the running switch accordingly.

{{< mermaid >}}
flowchart TD
    A["Management application"] -->|"Updates configuration"| B[("OVSDB")]
    B -->|"Configuration changes"| C["ovs-vswitchd"]
    C -->|"Applies changes"| D["Running switch"]
{{< /mermaid >}}

Suppose an application wants to add a bridge. Rather than needing to perform the low-level
networking operations itself, it changes the stored configuration to describe that bridge. The
daemon observes the change and does the work needed to realize it.

Notice what we've gained from this separation. The management application doesn't have to know how
to create every network resource, and the database doesn't have to implement network operations.
Each component has a narrower responsibility.

But we have also introduced a new problem.

> [!IMPORTANT]
> What happens when the configuration in the database and the running system don't match?

## Keeping Desired and Actual State in Sync

Suppose our desired configuration contains a bridge named `br0` with two ports, `eth1` and `eth2`.
However, only `eth1` is currently attached.

```text
Desired state          Actual state

br0                    br0
├── eth1               └── eth1
└── eth2
```

Something needs to recognize the difference and attempt to correct it. This
general process is called **reconciliation**.

{{< mermaid >}}
flowchart TD
    A["Read desired configuration"] --> B["Check relevant runtime state"]
    B --> C{"Does it match?"}
    C -->|"No"| D["Apply needed changes"]
    D --> B
    C -->|"Yes"| E["Wait for an event or recheck"]
    E --> A
{{< /mermaid >}}

The important part is that the **desired configuration remains a reference**.
If the daemon restarts, it can reload the desired configuration and work toward
restoring the expected state. The same principle can help recover from
unexpected runtime changes, assuming the controller can detect them.

That brings us to why someone might choose this architecture in the first place.

## Why Choose This Model?

Let's say the daemon crashes after creating a bridge but before attaching its second port.

In an operation-driven implementation, we might need some additional bookkeeping to know which steps
were completed and which ones should be retried. Otherwise, how would the service know where to
resume? This can certainly be solved in an imperative design, but it's something we have to build.

With a persistent desired-state configuration, the daemon can reload what should exist, examine the
relevant runtime state, and work toward whatever is missing. It doesn't necessarily need to replay
the history of commands.

Another benefit is that the component accepting configuration doesn't have to wait for every
underlying operation to finish. Changes can be recorded first and applied asynchronously. This is
useful when operations are slow, depend on external resources, or may need to be retried.

We also get a cleaner separation of responsibilities. Management clients deal with configuration;
the daemon deals with the details of applying it. We may change the implementation without changing
how clients describe the configuration.

These are useful properties, especially for infrastructure services managing long-lived resources.
But the separation doesn't make the difficult parts disappear. In some ways, it creates new ones.

## What Does Success Mean Now?

Consider an application updating the database to add a new port. The database accepts the
transaction. Does that mean the port exists?

Not necessarily. The daemon may not have processed the change yet. Or perhaps it tried, but the
underlying network interface doesn't exist.

We can have a perfectly valid stored configuration that the running system cannot satisfy.

This changes what **success** means in our API. Are we promising that the configuration was stored?
That the daemon processed it? Or that the resource is fully operational?

Those are different guarantees. OVS has mechanisms to acknowledge that its daemon has processed
configuration, but that acknowledgement doesn't necessarily prove that every external resource is
healthy.

A system using this architecture needs to decide how to communicate progress, errors, and the
difference between what has been requested and what is actually working.

## Partial Failures and Idempotency

Let's return to the bridge with two ports.

The daemon creates the bridge, attaches `eth1`, and then crashes before attaching `eth2`. After
restarting, repeating the same operations blindly might fail because some resources already exist.

Ideally, reconciliation should be **idempotent**: repeated attempts to reach the same desired state
shouldn't create duplicate resources or unexpected side effects.

This means checking not only whether a resource exists, but whether it's configured correctly. An
existing port attached to the wrong bridge isn't necessarily a successful result.

It gets harder when operations have side effects or aren't safe to repeat. The daemon might also
need retry policies, error reporting, and ways to deal with dependencies that remain unavailable.

In other words, the management interface is simpler partly because the daemon has taken
responsibility for more of each resource's lifecycle.

## A Database Transaction Isn't the Whole Operation

There's another interesting problem: **atomicity**.

Suppose we commit a database transaction requesting three new bridges. The database can commit all
three configuration changes together. But the daemon must still create the actual resources, and
those operations might not all succeed.

{{< mermaid >}}
flowchart TD
    A["Database transaction committed"] --> B["Daemon applies configuration"]
    B --> C["Bridge A: success"]
    B --> D["Bridge B: success"]
    B --> E["Bridge C: failure"]
{{< /mermaid >}}

The database is consistent, but reality only partially matches it.

**Atomicity in the database doesn't automatically extend to operations outside the database.**

Depending on the requirements, we might accept partial progress, retry the failed operations, or
introduce more coordination. There's no single answer that works for every system.

Another question is what happens when the desired state changes while an earlier change is still
being applied.

Imagine someone requests an MTU of `1400`, then immediately changes it to `1500`. Does the daemon
need to apply both values? Often it doesn't; reaching the latest desired configuration may be
enough.

However, an older asynchronous operation shouldn't finish late and overwrite a newer one. This may
require tracking configuration versions, detecting stale work, or carefully ordering operations.

And what if two clients continually write conflicting configurations? The database can serialize
transactions, but it can't decide which client's intention should ultimately win. Configuration
ownership is another problem we need to think about.

## Is This Always a Good Idea?

Not necessarily.

This approach comes with the cost of storing and synchronizing configuration, keeping track of
progress, handling retries, and reconciling partially applied changes. Splitting the components into
independent processes introduces its own operational concerns as well.

For some services, directly executing an operation and returning the result is entirely reasonable,
even at a large scale. Adding a persistent desired-state model and a controller without a clear need
for them may only complicate the system.

On the other hand, the approach becomes more attractive when we're managing long-lived resources,
need to recover from partial failures, or want the system to continue working toward a configuration
even when an operation cannot succeed immediately.

I think a useful question is whether we're asking the system to **perform an operation once**, or to
**maintain a condition over time**.

For the latter, desired-state reconciliation can be a natural fit.

## Conclusion

What originally interested me about OVS wasn't just that it uses declarative configuration. It was
how it separates the database describing the network from the daemon responsible for making that
description real.

On the surface, it's a simple design: store what should exist, then let another component apply it.
But that separation raises questions about reconciliation, idempotency, partial failures,
consistency, and even the meaning of a successful request.

The benefit is that configuration can serve as a persistent reference for recovery, while clients
don't need to understand every implementation detail. The cost is that keeping the running system
aligned with that reference becomes a responsibility of its own.

Like many engineering trade-offs, we're not really eliminating complexity. We're moving it to a
different part of the system in exchange for properties that may be more valuable for our use case.

Thanks for reading, and see you in the next post :)

## Further Reading

- [Open vSwitch Documentation](https://docs.openvswitch.org/en/latest/)
- [OVSDB Management Protocol (RFC 7047)](https://www.rfc-editor.org/rfc/rfc7047)
- [Kubernetes Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)
