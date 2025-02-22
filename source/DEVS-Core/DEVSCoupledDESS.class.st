Class {
	#name : 'DEVSCoupledDESS',
	#superclass : 'DEVSCoupledComponent',
	#category : 'DEVS-Core-Continuous',
	#package : 'DEVS-Core',
	#tag : 'Continuous'
}

{ #category : 'as yet unclassified' }
DEVSCoupledDESS >> addInputNPortNamed: n [

	^ self addInputPortOfType: DEVSInputNPort named: n
]

{ #category : 'as yet unclassified' }
DEVSCoupledDESS >> addOutputNPortNamed: n [

	^ self addOutputPortOfType: DEVSOutputNPort named: n
]

{ #category : 'as yet unclassified' }
DEVSCoupledDESS >> newSimulator [

	^ DEVnDESSRootSolver new 
		component: self;
		yourself
]

{ #category : 'as yet unclassified' }
DEVSCoupledDESS >> newSimulatorRT [

	^ DEVnDESSRootSolverRT new 
		component: self;
		yourself
]

{ #category : 'as yet unclassified' }
DEVSCoupledDESS >> receiveNMsgStarTime: t step: h [

	| yy xx yetUnevaluatedFunctions toEvaluate |

	"get output from (send '*' to) all blocks with integrators and collect their outputs"
	yy := Dictionary new.	
	(components values select: [ :c | (c isKindOf: DEVSCoupledDESS) | (c isKindOf: DEVSAtomicDESS) ]) 
		do: [ :c | (c receiveNMsgStarTime: t step: h) associationsDo: [ :a | yy add: a ] ].

	"evaluate memoryless fast blocks with defined inputs while it is possible 
	 (each block is evaluated max 1 time)"
	yetUnevaluatedFunctions := components values select: [ :c | (c isKindOf: DEVSInstantaneousFunction) ].
	toEvaluate := OrderedCollection new.
	[ toEvaluate size = yetUnevaluatedFunctions size ] whileFalse: [ 
	  toEvaluate := yetUnevaluatedFunctions copy.
	  toEvaluate do: [ :c | | ready |	
		xx := Dictionary new. ready := true.
		(c inputPorts select: [ :p | p isKindOf: DEVSInputNPort]) do: [ :p | p inLines do: [ :pi |	
			(yy keys includes: pi) ifTrue: [ xx at: p put: (yy at: pi) ] ifFalse: [ ready := false ]]].
		ready ifTrue: [ 
			(c receiveNMsgX: xx time: t step: h) associationsDo: [ :a | yy add: a ]. 
			yetUnevaluatedFunctions remove: c ]]].

	"define output of self"
	output := Dictionary new.
	(outputPorts select: [ :p | p isKindOf: DEVSOutputNPort]) do: [ :p | p inLines do: [ :pi |
		(yy keys includes: pi) ifTrue: [ output at: p put: (yy at: pi) ]]].

	^ output

]

{ #category : 'as yet unclassified' }
DEVSCoupledDESS >> receiveNMsgX: x time: t step: h [

	| xx yy |

	(timeLast <= t) & (t <= timeNext) ifFalse: [ self error: 'Bad Synchronization' ].

	input := x.

	"collect previously generated outputs from all numeric components, including self's input"
	yy := Dictionary new.
	input associationsDo: [ :a | (a key isKindOf: DEVSInputNPort) ifTrue: [ yy add: a ] ].
	(components values select: [ :c | (c isKindOf: DEVSCoupledDESS) | (c isKindOf: DEVSAtomicDESS) | 
	   (c isKindOf: DEVSInstantaneousFunction) ]) 
		do: [ :c | c output associationsDo: [ :a | 
			(a key isKindOf: DEVSOutputNPort) ifTrue: [ yy add: a ] ] ].

	"evaluate all numeric components with appropriate inputs - make integration step"
	(components values select: [ :c | (c isKindOf: DEVSCoupledDESS) | (c isKindOf: DEVSAtomicDESS) ]) 
	  do: [ :c |
		xx := Dictionary new.
		(c inputPorts select: [ :p | p isKindOf: DEVSInputNPort]) do: [ :p | p inLines do: [ :pi |
			(yy keys includes: pi) ifTrue: [ xx at: p put: (yy at: pi) ]]].
		c receiveNMsgX: xx time: t step: h ].


]
