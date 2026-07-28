#include "example_node.h"

void ExampleNode::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_READY: {
			print_line("The example engine module node has been added to the scene tree and is now ready!");
		} break;
	}
}

void ExampleNode::print_hello() const {
	print_line("Hello, World!");
}

String ExampleNode::return_hello() const {
	return "Hello, World!";
}

void ExampleNode::_bind_methods() {
	ClassDB::bind_method(D_METHOD("print_hello"), &ExampleNode::print_hello);
	ClassDB::bind_method(D_METHOD("return_hello"), &ExampleNode::return_hello);
}
