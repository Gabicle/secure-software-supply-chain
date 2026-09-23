import { useEffect, useState } from 'react'
import './App.css'

function App() {
  const [items, setItems] = useState([])
  const [name, setName] = useState('')

  async function loadItems() {
    const response = await fetch('/api/items')
    const data = await response.json()
    setItems(data)
  }

  async function addItem(event) {
    event.preventDefault()

    await fetch('/api/items', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name }),
    })

    setName('')
    await loadItems()
  }

  useEffect(() => {
    async function fetchItems() {
      const response = await fetch('/api/items')
      const data = await response.json()
      setItems(data)
    }

    fetchItems()
  }, [])

  return (
    <main>
      <h1>Supply Chain Demo</h1>

      <form onSubmit={addItem}>
        <input
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Item name"
          required
        />
        <button type="submit">Add item</button>
      </form>

      <ul>
        {items.map((item) => (
          <li key={item.id}>
            {item.id}: {item.name}
          </li>
        ))}
      </ul>
    </main>
  )
}

export default App