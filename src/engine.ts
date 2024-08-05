type System = (engine: Engine) => void;

export class Engine {
    private systems: System[];

    public constructor() {
        this.systems = [];
    }

    public addSystem(system: System) {
        this.systems.push(system);
    }

    public run() {
        this.systems.forEach(system => {
            system(this);
        });
    }
}
