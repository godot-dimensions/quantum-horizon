#pragma once

#include "quantum_horizon_defines.h"

#include "scene/main/node.h"

class ExampleNode : public Node {
	GDCLASS(ExampleNode, Node);

protected:
	static void _bind_methods();
	void _notification(int p_what);

public:
	void print_hello() const;
	String return_hello() const;
};
