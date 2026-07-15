import { Controller } from "@hotwired/stimulus"

// Renders a generation-based family tree (portraits + parent/spouse edges) with
// pan and zoom. Viewpoint relabelling is layered on in selectViewpoint().
export default class extends Controller {
  static values = {
    nodes: Array,
    parentEdges: Array,
    spouseEdges: Array,
    terms: Object
  }

  static NODE_W = 120
  static NODE_H = 96
  static H_GAP = 40
  static V_GAP = 70

  connect() {
    this.viewpointId = null
    this.positions = new Map()
    this.nodeEls = new Map()
    this.buildStage()
    this.layout()
    this.draw()
    this.setupPanZoom()
  }

  buildStage() {
    this.element.style.position = "relative"
    this.element.style.cursor = "grab"

    this.world = document.createElement("div")
    this.world.style.position = "absolute"
    this.world.style.top = "0"
    this.world.style.left = "0"
    this.world.style.transformOrigin = "0 0"
    this.element.appendChild(this.world)

    this.svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    this.svg.style.position = "absolute"
    this.svg.style.overflow = "visible"
    this.world.appendChild(this.svg)

    this.tx = 40
    this.ty = 40
    this.scale = 1
  }

  layout() {
    const { NODE_W, NODE_H, H_GAP, V_GAP } = this.constructor
    const byLevel = new Map()
    this.nodesValue.forEach((n) => {
      const bucket = byLevel.get(n.level) || []
      bucket.push(n)
      byLevel.set(n.level, bucket)
    })

    let maxX = 0
    let maxY = 0
    byLevel.forEach((bucket, level) => {
      bucket.forEach((n, i) => {
        const x = i * (NODE_W + H_GAP)
        const y = level * (NODE_H + V_GAP)
        this.positions.set(n.id, { x, y })
        maxX = Math.max(maxX, x + NODE_W)
        maxY = Math.max(maxY, y + NODE_H)
      })
    })
    this.svg.setAttribute("width", maxX)
    this.svg.setAttribute("height", maxY)
  }

  draw() {
    this.drawEdges(this.parentEdgesValue, "parent")
    this.drawEdges(this.spouseEdgesValue, "spouse")
    this.nodesValue.forEach((n) => this.drawNode(n))
  }

  center(id) {
    const p = this.positions.get(id)
    return { x: p.x + this.constructor.NODE_W / 2, y: p.y + this.constructor.NODE_H / 2 }
  }

  drawEdges(edges, kind) {
    edges.forEach(([a, b]) => {
      if (!this.positions.has(a) || !this.positions.has(b)) return
      const from = this.center(a)
      const to = this.center(b)
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", from.x)
      line.setAttribute("y1", from.y)
      line.setAttribute("x2", to.x)
      line.setAttribute("y2", to.y)
      line.setAttribute("stroke", kind === "spouse" ? "#f472b6" : "#cbd5e1")
      line.setAttribute("stroke-width", "2")
      if (kind === "spouse") line.setAttribute("stroke-dasharray", "4 3")
      this.svg.appendChild(line)
    })
  }

  drawNode(n) {
    const { x, y } = this.positions.get(n.id)
    const card = document.createElement("div")
    card.dataset.nodeId = n.id
    card.style.cssText =
      `position:absolute;left:${x}px;top:${y}px;width:${this.constructor.NODE_W}px;` +
      "display:flex;flex-direction:column;align-items:center;text-align:center;cursor:pointer;"

    const avatar = document.createElement("div")
    avatar.style.cssText =
      "width:48px;height:48px;border-radius:9999px;overflow:hidden;display:flex;" +
      "align-items:center;justify-content:center;background:#e0e7ff;color:#4338ca;font-weight:600;"
    if (n.portrait_url) {
      const img = document.createElement("img")
      img.src = n.portrait_url
      img.alt = n.name
      img.style.cssText = "width:100%;height:100%;object-fit:cover;"
      avatar.appendChild(img)
    } else {
      avatar.textContent = (n.name || "?").charAt(0)
    }

    const name = document.createElement("div")
    name.className = "node-name"
    name.textContent = n.name
    name.style.cssText = "margin-top:4px;font-size:12px;font-weight:600;color:#111827;"

    const term = document.createElement("div")
    term.className = "node-term"
    term.dataset.nodeTerm = n.id
    term.style.cssText = "font-size:12px;color:#4f46e5;min-height:16px;"

    card.append(avatar, name, term)
    card.addEventListener("click", (e) => {
      e.stopPropagation()
      this.selectViewpoint(n.id)
    })
    this.world.appendChild(card)
    this.nodeEls.set(n.id, card)
  }

  // Overridden behaviour arrives in T4.6; base version is a no-op hook.
  selectViewpoint(_id) {}

  setupPanZoom() {
    this.applyTransform()

    let dragging = false
    let startX = 0
    let startY = 0
    this.element.addEventListener("pointerdown", (e) => {
      dragging = true
      startX = e.clientX - this.tx
      startY = e.clientY - this.ty
      this.element.style.cursor = "grabbing"
    })
    window.addEventListener("pointermove", (e) => {
      if (!dragging) return
      this.tx = e.clientX - startX
      this.ty = e.clientY - startY
      this.applyTransform()
    })
    window.addEventListener("pointerup", () => {
      dragging = false
      this.element.style.cursor = "grab"
    })
    this.element.addEventListener("wheel", (e) => {
      e.preventDefault()
      const factor = e.deltaY < 0 ? 1.1 : 0.9
      this.scale = Math.min(2.5, Math.max(0.3, this.scale * factor))
      this.applyTransform()
    }, { passive: false })
  }

  applyTransform() {
    this.world.style.transform = `translate(${this.tx}px, ${this.ty}px) scale(${this.scale})`
  }
}
